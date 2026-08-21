import { Injectable } from '@nestjs/common';

@Injectable()
export class AuthService {
  
  async getUserProfile(userId: string, email?: string, role?: string) {
    const finalRole = role || 'user';

    console.log(`Login Check -> UserID: ${userId} | Role: ${finalRole}`);

    return {
      userId: userId,
      email: email || 'Email not provided',
      role: finalRole, 
      status: 'Authenticated',
    };
  }
}