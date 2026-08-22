import { BadRequestException, Controller, Get, Res, Req, Headers, Param, Query, UnauthorizedException } from '@nestjs/common';
import { createHash, randomBytes, scrypt, timingSafeEqual } from 'crypto';
import { Response, Request } from 'express';
import { PrismaService } from '../prisma.service';
import { JwtService } from '@nestjs/jwt'; // <-- Import JwtService
import { Body, Post } from '@nestjs/common';

@Controller('auth')
export class AuthController {
  
  // Inject both Prisma and the new JWT Service
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService
  ) {}

  private async invitedRole(email: string) {
    const invite = await this.prisma.adminInvite.findFirst({
      where: { email: email.toLowerCase(), acceptedAt: null, expiresAt: { gt: new Date() } },
    });
    return invite ? { role: invite.role, inviteId: invite.id } : null;
  }

  private async markInviteAccepted(inviteId?: string) {
    if (inviteId) await this.prisma.adminInvite.update({ where: { id: inviteId }, data: { acceptedAt: new Date() } });
  }

  private derivePassword(password: string, salt: string): Promise<Buffer> {
    return new Promise((resolve, reject) => {
      scrypt(password, salt, 64, (error, key) => error ? reject(error) : resolve(key as Buffer));
    });
  }

  private async hashLocalPassword(password: string) {
    const salt = randomBytes(16).toString('hex');
    const key = await this.derivePassword(password, salt);
    return `scrypt$${salt}$${key.toString('hex')}`;
  }

  private async verifyLocalPassword(password: string, stored: string) {
    const [algorithm, salt, expectedHex] = stored.split('$');
    if (algorithm !== 'scrypt' || !salt || !expectedHex) return false;
    const expected = Buffer.from(expectedHex, 'hex');
    const actual = await this.derivePassword(password, salt);
    return actual.length === expected.length && timingSafeEqual(actual, expected);
  }

  @Get('partner-invite')
  openPartnerInvite(@Query('token') token: string, @Res() res: Response) {
    if (!token) return res.status(400).send('This invitation link is missing its token.');
    const deepLinkBase = process.env.PARTNER_INVITE_URL || 'caviteexplorer://accept-invite';
    const deepLink = `${deepLinkBase}${deepLinkBase.includes('?') ? '&' : '?'}token=${encodeURIComponent(token)}`;
    const intentLink = `intent://accept-invite?token=${encodeURIComponent(token)}#Intent;scheme=caviteexplorer;package=com.example.cavite_explorer_mobile;end`;
    const safeDeepLink = deepLink.replace(/&/g, '&amp;').replace(/"/g, '&quot;');
    const safeIntentLink = intentLink.replace(/&/g, '&amp;').replace(/"/g, '&quot;');
    return res.type('html').send(`<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Open Cavite Explorer</title><style>
body{margin:0;background:#f6f6f0;color:#17241f;font-family:Arial,sans-serif;display:grid;min-height:100vh;place-items:center;padding:24px;box-sizing:border-box}.card{width:min(100%,420px);background:white;border:1px solid #dce5df;border-radius:24px;padding:30px;box-sizing:border-box;box-shadow:0 18px 45px #123d2b1f;text-align:center}.mark{width:58px;height:58px;margin:0 auto 18px;border-radius:18px;background:#176a50;color:white;display:grid;place-items:center;font-weight:800;font-size:20px}h1{font-size:25px;margin:0 0 10px}p{color:#647069;line-height:1.5}.button{display:block;margin-top:24px;background:#176a50;color:white;text-decoration:none;font-weight:700;padding:15px 18px;border-radius:12px}.hint{font-size:12px;margin-top:16px}
</style></head><body><main class="card"><div class="mark">CE</div><h1>Partner invitation</h1><p>Open Cavite Explorer to create your password and complete your partner profile.</p><a class="button" href="${safeIntentLink}">Open Cavite Explorer</a><p class="hint">If Android does not open the app, try the direct app link below.</p><a href="${safeDeepLink}">Try direct app link</a></main></body></html>`);
  }

  @Get('google')
  async startGoogleLogin(@Query('client') client: string, @Res() res: Response) {
    try {
      const neonUrl = process.env.NEON_AUTH_URL;
      const frontendUrl = process.env.FRONTEND_URL;
      const backendUrl = process.env.BACKEND_URL;
      const callbackUrl = client === 'web'
        ? `${process.env.WEB_BACKEND_URL || backendUrl}/auth/callback`
        : (process.env.MOBILE_AUTH_CALLBACK_URL || `${backendUrl}/auth/callback`);

      if (!neonUrl || !frontendUrl || !backendUrl) throw new Error("Neon Auth configuration is incomplete");

      const response = await fetch(neonUrl, {
        method: 'POST',
        headers: { 
          'Content-Type': 'application/json',
          'Origin': frontendUrl,
          'Referer': `${frontendUrl}/`
        },
        body: JSON.stringify({
          provider: 'google',
          callbackURL: callbackUrl,
        }),
      });
      
      const data = await response.json();
      if (response.ok && data.url) return res.redirect(data.url);
      
      return res.status(response.status).json({ message: "Failed", details: data });
    } catch (error: any) {
      return res.status(500).json({ error: error.message });
    }
  }

 @Get('callback')
  async handleGoogleCallback(@Req() req: Request, @Res() res: Response) {
    const verifier = (req.query.token || req.query.session_token || req.query.code || req.query.neon_auth_session_verifier) as string;

    if (!verifier) return res.redirect(`caviteexplorer://login-callback?error=LoginCanceled`);

    try {
      // FIX: We now look for the user attached to the MOST RECENT SESSION.
      // This works 100% of the time, whether it's a new user or a returning user!
      const userResult: any[] = await this.prisma.$queryRaw`
        SELECT u.id, u.name, u.email 
        FROM neon_auth."user" u
        JOIN neon_auth.session s ON u.id = s."userId"
        ORDER BY s."createdAt" DESC 
        LIMIT 1
      `;

      if (userResult && userResult.length > 0) {
        const user = userResult[0];

        // --- ADD THIS PRISMA SYNC BLOCK ---
        const invitation = await this.invitedRole(user.email);
        const appUser = await this.prisma.user.upsert({
          where: { id: user.id }, 
          // Preserve role and access settings that an administrator set in the database.
          update: { name: user.name },
          create: {
            id: user.id,
            email: user.email,
            name: user.name,
            password: "MANAGED_BY_NEON", // <-- ADD THIS LINE
            role: invitation?.role ?? 'user',
          }
        });
        if (!appUser.isActive) {
          return res.redirect('caviteexplorer://login-callback?error=AccountDisabled');
        }
        await this.markInviteAccepted(invitation?.inviteId);
        // ----------------------------------

        const payload = { sub: user.id, name: user.name, email: user.email };
        const signedJwt = this.jwtService.sign(payload);

        console.log(`🔐 Google Login Success & Synced to Prisma: ${user.name}`);

        const deepLink = `caviteexplorer://login-callback?token=${signedJwt}`;
        return res.redirect(deepLink);
      } else {
        console.warn("⚠️ No sessions found in the database.");
      }
    } catch (error: any) {
      console.error("🚨 Auth Callback Crash:", error.message);
    }
    
    return res.redirect(`caviteexplorer://login-callback?error=UserNotFound`);
  }
  // ==========================================
  // BRAND NEW: The Secure Profile Endpoint
  // ==========================================
  @Get('me')
  async getProfile(@Headers('authorization') authHeader: string) {
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new UnauthorizedException('Missing or invalid token');
    }

    const token = authHeader.split(' ')[1];

    try {
      const decodedUser = this.jwtService.verify(token);
      
      // Fetch the full profile from PRISMA, not just the token!
      const userProfile = await this.prisma.user.findUnique({
        where: { id: decodedUser.sub }
      });
      if (!userProfile) throw new UnauthorizedException('User no longer exists');
      if (!userProfile.isActive) throw new UnauthorizedException('This account has been disabled');
      
      return {
        message: "Secure data retrieved",
        user: {
          id: decodedUser.sub,
          name: userProfile?.name || decodedUser.name,
          email: decodedUser.email,
          role: userProfile?.role || 'user',
          mobile: userProfile?.mobile || '',
          birthday: userProfile?.birthday || '',
          sex: userProfile?.sex || '',
        }
      };
    } catch (error) {
      if (error instanceof UnauthorizedException) throw error;
      throw new UnauthorizedException('Token expired or invalid');
    }
  }

 @Post('register')
  async registerUser(@Body() body: { email: string; password: string; name: string }, @Res() res: Response) {
    try {
      // 1. Grab all the required URLs from .env
      const neonAuthUrl = process.env.NEON_AUTH_URL;
      const frontendUrl = process.env.FRONTEND_URL;
      const backendUrl = process.env.BACKEND_URL;

      if (!neonAuthUrl || !frontendUrl || !backendUrl) {
        throw new Error("CRITICAL: Missing environment variables in .env");
      }

      const neonSignupUrl = neonAuthUrl.replace('/sign-in/social', '/sign-up/email');
      console.log("Attempting to register user at:", neonSignupUrl);

      // 2. Add the missing headers and callbackURL!
      const response = await fetch(neonSignupUrl, {
        method: 'POST',
        headers: { 
          'Content-Type': 'application/json',
          'Origin': frontendUrl,       // <-- FIX: Tells Neon who we are
          'Referer': `${frontendUrl}/` // <-- FIX: Security requirement
        },
        body: JSON.stringify({
          email: body.email,
          password: body.password,
          name: body.name,
          callbackURL: `${backendUrl}/auth/callback`, // <-- FIX: Where to send the email verification link
        }),
      });

      const data = await response.json();

      if (response.ok) {
        return res.status(201).json({ message: "Registration successful. Please check your email." });
      } else {
        console.error("❌ NEON REJECTED SIGNUP:", data);
        return res.status(response.status).json({ message: data.message || "Registration failed" });
      }
      
    } catch (error: any) {
      console.error("🚨 SIGN UP CRASH:", error); 
      return res.status(500).json({ message: "Internal server error", error: error.message });
    }
  }

 @Post('login')
  async loginUser(@Body() body: { email: string; password: string }, @Res() res: Response) {
    try {
      const email = body.email?.trim().toLowerCase();
      const localUser = email ? await this.prisma.user.findUnique({ where: { email } }) : null;
      if (localUser?.password.startsWith('scrypt$')) {
        const passwordMatches = await this.verifyLocalPassword(body.password || '', localUser.password);
        if (!passwordMatches) return res.status(401).json({ message: 'Invalid credentials.' });
        if (!localUser.isActive) return res.status(403).json({ message: 'This account has been disabled. Contact an administrator.' });
        const token = this.jwtService.sign({ sub: localUser.id, name: localUser.name, email: localUser.email });
        return res.status(200).json({
          message: 'Login successful',
          token,
          user: { id: localUser.id, name: localUser.name, email: localUser.email, role: localUser.role },
        });
      }

      const neonAuthUrl = process.env.NEON_AUTH_URL;
      const frontendUrl = process.env.FRONTEND_URL;

      if (!neonAuthUrl || !frontendUrl) {
        throw new Error("CRITICAL: Missing environment variables");
      }

      // 1. FIX: Use the correct endpoint name (/sign-in/email)
      const neonSignInUrl = neonAuthUrl.replace('/sign-in/social', '/sign-in/email');
      console.log(`Attempting to login user: ${body.email} at ${neonSignInUrl}`);

      const response = await fetch(neonSignInUrl, {
        method: 'POST',
        headers: { 
          'Content-Type': 'application/json',
          'Origin': frontendUrl, 
        },
        body: JSON.stringify({
          email: body.email,
          password: body.password,
        }),
      });

      // 2. THE BULLETPROOF VEST: Read as text first to prevent the JSON crash
      const responseText = await response.text();
      let data;
      try {
        data = responseText ? JSON.parse(responseText) : {};
      } catch (parseError) {
        console.error("❌ NEON SENT NON-JSON RESPONSE:", responseText);
        return res.status(response.status).json({ message: "Invalid response from auth server." });
      }

      if (response.ok && data.user) {
        
        // --- ADD THIS PRISMA SYNC BLOCK ---
        // This ensures the user exists in YOUR database before we give them a token
        const invitation = await this.invitedRole(data.user.email);
        const appUser = await this.prisma.user.upsert({
          where: { id: data.user.id }, 
          // A login must never overwrite a role assigned in the database.
          update: { name: data.user.name },
          create: {
            id: data.user.id,
            email: data.user.email,
            name: data.user.name,
            password: "MANAGED_BY_NEON", // <-- ADD THIS LINE
            role: invitation?.role ?? 'user',
          }
        });
        if (!appUser.isActive) {
          return res.status(403).json({ message: 'This account has been disabled. Contact an administrator.' });
        }
        await this.markInviteAccepted(invitation?.inviteId);
        // ----------------------------------

        const payload = { sub: data.user.id, name: data.user.name, email: data.user.email };
        const signedJwt = this.jwtService.sign(payload);

        console.log(`🔐 Manual Login Success & Synced to Prisma: ${data.user.name}`);

        return res.status(200).json({ 
          message: "Login successful", 
          token: signedJwt,
          user: { ...data.user, role: appUser.role }
        });

      } else {
        console.error("❌ NEON REJECTED LOGIN:", data);
        return res.status(response.status).json({ message: data.message || "Invalid credentials." });
      }
      
    } catch (error: any) {
      console.error("🚨 LOGIN CRASH:", error); 
      return res.status(500).json({ message: "Internal server error", error: error.message });
    }
  }

  @Get('invitations/:token')
  async invitation(@Param('token') token: string) {
    const tokenHash = createHash('sha256').update(token).digest('hex');
    const invite = await this.prisma.adminInvite.findFirst({
      where: { tokenHash, acceptedAt: null, expiresAt: { gt: new Date() } },
      select: { email: true, name: true, role: true, expiresAt: true },
    });
    if (!invite) throw new BadRequestException('This invitation link is invalid, expired, or was already used.');
    return invite;
  }

  @Post('invitations/accept')
  async acceptInvitation(@Body() body: { token: string; password: string }, @Res() res: Response) {
    if (!body.password || body.password.length < 8) return res.status(400).json({ message: 'Use a password with at least 8 characters.' });
    const tokenHash = createHash('sha256').update(body.token || '').digest('hex');
    const invite = await this.prisma.adminInvite.findFirst({ where: { tokenHash, acceptedAt: null, expiresAt: { gt: new Date() } } });
    if (!invite) return res.status(400).json({ message: 'This invitation link is invalid, expired, or was already used.' });
    const neonAuthUrl = process.env.NEON_AUTH_URL;
    const frontendUrl = process.env.ADMIN_WEB_URL || process.env.FRONTEND_URL;
    if (!neonAuthUrl || !frontendUrl) return res.status(500).json({ message: 'Server authentication configuration is incomplete.' });
    const invitedName = invite.name?.trim() || invite.email
      .split('@')[0]
      .split(/[._-]+/)
      .filter(Boolean)
      .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
      .join(' ') || 'Cavite Explorer Partner';

    if (invite.role === 'partner') {
      const password = await this.hashLocalPassword(body.password);
      const partner = await this.prisma.user.upsert({
        where: { email: invite.email },
        update: { name: invitedName, password, role: 'partner', isActive: true },
        create: { email: invite.email, name: invitedName, password, role: 'partner', isActive: true },
      });
      await this.markInviteAccepted(invite.id);
      const token = this.jwtService.sign({ sub: partner.id, name: partner.name, email: partner.email });
      return res.status(200).json({
        message: 'Partner account created and signed in.',
        token,
        user: { id: partner.id, name: partner.name, email: partner.email, role: partner.role },
      });
    }

    const signUpPayload: Record<string, unknown> = {
      email: invite.email,
      password: body.password,
      name: invitedName,
    };
    // Partner signup already continues inside the installed mobile app. Supplying
    // a local callback here makes Neon validate a development-only URL and reject
    // the account before it is created. Web invitations still need their callback.
    if (invite.role !== 'partner') signUpPayload.callbackURL = frontendUrl;
    const response = await fetch(neonAuthUrl.replace('/sign-in/social', '/sign-up/email'), {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Origin: frontendUrl, Referer: `${frontendUrl}/` },
      body: JSON.stringify(signUpPayload),
    });
    const text = await response.text();
    let result: any = {}; try { result = text ? JSON.parse(text) : {}; } catch {}
    if (!response.ok) return res.status(response.status).json({ message: result.message || 'Could not create the invited account.' });
    // Neon may require email verification. The assigned role is applied on first successful sign-in.
    return res.status(200).json({ message: invite.role === 'partner' ? 'Partner account created. Verify your email if requested, then sign in in the mobile app.' : 'Account created. Verify your email if requested, then sign in to the admin portal.' });
  }

  @Post('forgot-password')
  async forgotPassword(@Body() body: { email: string; client?: 'mobile' | 'web' }, @Res() res: Response) {
    try {
      const neonAuthUrl = process.env.NEON_AUTH_URL;
      const frontendUrl = process.env.FRONTEND_URL;
      const client = body.client === 'web' ? 'web' : 'mobile';
      const backendUrl = client === 'web'
        ? (process.env.WEB_BACKEND_URL || process.env.BACKEND_URL)
        : (process.env.MOBILE_BACKEND_URL || process.env.BACKEND_URL);
      const redirectTo = client === 'web'
        ? process.env.WEB_RESET_URL
        : (process.env.MOBILE_RESET_CALLBACK_URL || `${process.env.BACKEND_URL}/auth/reset-callback`);

      if (!neonAuthUrl || !frontendUrl || !redirectTo) {
        throw new Error("CRITICAL: Missing environment variables");
      }

      // 1. FIX: The correct endpoint to trigger the email is /forgot-password
      // CORRECT: The updated API route for password resets!
      const neonResetUrl = neonAuthUrl.replace('/sign-in/social', '/request-password-reset');
      console.log(`Attempting to send password reset to: ${body.email} at ${neonResetUrl}`);
      console.log(`Password reset client: ${client}; redirect: ${redirectTo}`);

      const response = await fetch(neonResetUrl, {
        method: 'POST',
        headers: { 
          'Content-Type': 'application/json',
          'Origin': frontendUrl, 
        },
        body: JSON.stringify({
          email: body.email,
          // CHANGE THIS LINE: Use 'redirectTo' instead of 'callbackURL'
          redirectTo
        }),
      });

      const responseText = await response.text();
      let data = {};
      try {
        data = responseText ? JSON.parse(responseText) : {};
      } catch (e) {}

      if (response.ok) {
        return res.status(200).json({ message: "Password reset link sent!" });
      } else {
        console.error("❌ NEON REJECTED RESET:", data);
        return res.status(response.status).json({ message: data['message'] || "Failed to send reset link." });
      }
      
    } catch (error: any) {
      console.error("🚨 RESET CRASH:", error); 
      return res.status(500).json({ message: "Internal server error" });
    }
  }

  @Get('reset-callback')
  async handleResetCallback(@Req() req: Request, @Res() res: Response) {
    // 1. Catch the token Neon put in the URL
    const token = req.query.token as string;
    const client = req.query.client === 'web' ? 'web' : 'mobile';
    const mobileUrl = process.env.MOBILE_RESET_URL || 'caviteexplorer://reset-password';
    const webUrl = process.env.WEB_RESET_URL;

    if (!token) {
      const destination = client === 'web' && webUrl ? webUrl : mobileUrl;
      return res.redirect(`${destination}?error=NoTokenFound`);
    }

    console.log("🔄 Slingshotting user back to Flutter to set a new password!");
    
    // 2. Redirect the browser to open the Cavite Explorer app!
    const destination = client === 'web' ? webUrl : mobileUrl;
    if (!destination) return res.status(500).json({ message: 'Web password reset URL is not configured' });
    return res.redirect(`${destination}?token=${encodeURIComponent(token)}`);
  }

  @Post('reset-password')
  async resetPassword(@Body() body: { token: string; newPassword: string }, @Res() res: Response) {
    try {
      const neonAuthUrl = process.env.NEON_AUTH_URL;
      if (!neonAuthUrl) throw new Error("CRITICAL: Missing environment variables");

      // Remember earlier when Neon yelled at us about missing 'newPassword'? 
      // This is the correct endpoint for actually changing it!
      const neonResetUrl = neonAuthUrl.replace('/sign-in/social', '/reset-password');
      console.log(`Attempting to save new password with token...`);

      const response = await fetch(neonResetUrl, {
        method: 'POST',
        headers: { 
          'Content-Type': 'application/json',
          'Origin': process.env.FRONTEND_URL, 
        },
        body: JSON.stringify({
          newPassword: body.newPassword,
          token: body.token, // We pass the secure token so Neon knows exactly who is changing their password
        }),
      });

      const responseText = await response.text();
      let data = {};
      try {
        data = responseText ? JSON.parse(responseText) : {};
      } catch (e) {}

      if (response.ok) {
        return res.status(200).json({ message: "Password updated successfully!" });
      } else {
        console.error("❌ NEON REJECTED NEW PASSWORD:", data);
        return res.status(response.status).json({ message: data['message'] || "Failed to update password. Token may be expired." });
      }
      
    } catch (error: any) {
      console.error("🚨 SAVE PASSWORD CRASH:", error); 
      return res.status(500).json({ message: "Internal server error" });
    }
  }

  @Post('update-profile')
  async updateProfile(
    @Headers('authorization') authHeader: string, 
    @Body() body: { name: string; mobile: string; birthday: string; sex: string },
    @Res() res: Response
  ) {
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new UnauthorizedException('Missing or invalid token');
    }

    const token = authHeader.split(' ')[1];

    try {
      const decodedUser = this.jwtService.verify(token);
      const userId = decodedUser.sub;

      // 1. Save the new info securely into YOUR Prisma User table!
      await this.prisma.user.update({
        where: { id: userId },
        data: { 
          name: body.name,
          mobile: body.mobile, 
          birthday: body.birthday, 
          sex: body.sex 
        },
      });

      // (We removed the neon_auth sync block because Neon protects that table, 
      // and your Flutter app relies on your Prisma table anyway!)

      console.log(`✅ Profile updated successfully for: ${body.name}`);
      return res.status(200).json({ message: "Profile updated successfully!" });

    } catch (error) {
      console.error("🚨 Profile update failed:", error);
      return res.status(500).json({ message: "Failed to update profile" });
    }
  }
}
