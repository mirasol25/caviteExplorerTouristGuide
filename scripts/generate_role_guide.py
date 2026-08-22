from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import (
    BaseDocTemplate,
    Frame,
    Image,
    KeepTogether,
    PageBreak,
    PageTemplate,
    Paragraph,
    Spacer,
    Table,
    TableStyle,
)


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "output" / "pdf" / "Cavite-Explorer-Role-Workflows.pdf"
LOGO = ROOT / "cavite_explorer_mobile" / "assets" / "images" / "cavite-explorer-logo.png"

PAGE_W, PAGE_H = A4
GREEN = colors.HexColor("#176A50")
DARK_GREEN = colors.HexColor("#123F33")
LIME = colors.HexColor("#D8F270")
GOLD = colors.HexColor("#D9A33E")
INK = colors.HexColor("#1C2822")
MUTED = colors.HexColor("#66736C")
PALE = colors.HexColor("#F1F6F2")
WARM = colors.HexColor("#FAF8F3")
LINE = colors.HexColor("#D6E2DA")
BLUE = colors.HexColor("#3478E5")
ORANGE = colors.HexColor("#E96D38")


styles = getSampleStyleSheet()
styles.add(ParagraphStyle(
    name="CoverKicker", parent=styles["Normal"], fontName="Helvetica-Bold",
    fontSize=10, leading=13, textColor=LIME, alignment=TA_CENTER, spaceAfter=8,
    tracking=1.4,
))
styles.add(ParagraphStyle(
    name="CoverTitle", parent=styles["Title"], fontName="Helvetica-Bold",
    fontSize=30, leading=34, textColor=colors.white, alignment=TA_CENTER,
    spaceAfter=12,
))
styles.add(ParagraphStyle(
    name="CoverSub", parent=styles["Normal"], fontName="Helvetica",
    fontSize=12, leading=18, textColor=colors.HexColor("#D7E6DF"),
    alignment=TA_CENTER,
))
styles.add(ParagraphStyle(
    name="Kicker", parent=styles["Normal"], fontName="Helvetica-Bold",
    fontSize=8, leading=10, textColor=GREEN, spaceAfter=5, tracking=1.2,
))
styles.add(ParagraphStyle(
    name="H1x", parent=styles["Heading1"], fontName="Helvetica-Bold",
    fontSize=24, leading=28, textColor=DARK_GREEN, spaceAfter=9,
))
styles.add(ParagraphStyle(
    name="H2x", parent=styles["Heading2"], fontName="Helvetica-Bold",
    fontSize=15, leading=19, textColor=INK, spaceBefore=8, spaceAfter=6,
))
styles.add(ParagraphStyle(
    name="Bodyx", parent=styles["BodyText"], fontName="Helvetica",
    fontSize=9.4, leading=14, textColor=INK, spaceAfter=7,
))
styles.add(ParagraphStyle(
    name="Smallx", parent=styles["BodyText"], fontName="Helvetica",
    fontSize=7.8, leading=11, textColor=MUTED,
))
styles.add(ParagraphStyle(
    name="StepTitle", parent=styles["BodyText"], fontName="Helvetica-Bold",
    fontSize=10, leading=13, textColor=INK, spaceAfter=2,
))
styles.add(ParagraphStyle(
    name="StepBody", parent=styles["BodyText"], fontName="Helvetica",
    fontSize=8.4, leading=12, textColor=MUTED,
))
styles.add(ParagraphStyle(
    name="Callout", parent=styles["BodyText"], fontName="Helvetica-Bold",
    fontSize=9, leading=13, textColor=DARK_GREEN,
))
styles.add(ParagraphStyle(
    name="TableHead", parent=styles["Normal"], fontName="Helvetica-Bold",
    fontSize=7.4, leading=9, textColor=colors.white, alignment=TA_LEFT,
))
styles.add(ParagraphStyle(
    name="TableCell", parent=styles["Normal"], fontName="Helvetica",
    fontSize=7.2, leading=9.4, textColor=INK,
))


def on_page(canvas, doc):
    canvas.saveState()
    if doc.page == 1:
        canvas.setFillColor(DARK_GREEN)
        canvas.rect(0, 0, PAGE_W, PAGE_H, fill=1, stroke=0)
        canvas.setFillColor(GREEN)
        canvas.circle(PAGE_W - 15 * mm, PAGE_H - 18 * mm, 42 * mm, fill=1, stroke=0)
        canvas.setFillColor(colors.HexColor("#245F4D"))
        canvas.circle(10 * mm, 12 * mm, 34 * mm, fill=1, stroke=0)
    else:
        canvas.setFillColor(WARM)
        canvas.rect(0, 0, PAGE_W, PAGE_H, fill=1, stroke=0)
        canvas.setStrokeColor(LINE)
        canvas.line(18 * mm, 16 * mm, PAGE_W - 18 * mm, 16 * mm)
        canvas.setFont("Helvetica", 7.5)
        canvas.setFillColor(MUTED)
        canvas.drawString(18 * mm, 10.5 * mm, "Cavite Explorer - Role Workflows")
        canvas.drawRightString(PAGE_W - 18 * mm, 10.5 * mm, f"Page {doc.page}")
    canvas.restoreState()


def role_header(kicker, title, subtitle):
    return [
        Paragraph(kicker.upper(), styles["Kicker"]),
        Paragraph(title, styles["H1x"]),
        Paragraph(subtitle, styles["Bodyx"]),
        Spacer(1, 3 * mm),
    ]


def step(number, title, body, accent=GREEN):
    badge = Table(
        [[Paragraph(f"<b>{number}</b>", ParagraphStyle(
            "badge", parent=styles["Normal"], fontName="Helvetica-Bold",
            fontSize=10, textColor=colors.white, alignment=TA_CENTER,
        ))]],
        colWidths=[9 * mm], rowHeights=[9 * mm],
    )
    badge.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), accent),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("BOX", (0, 0), (-1, -1), 0, accent),
    ]))
    text = [Paragraph(title, styles["StepTitle"]), Paragraph(body, styles["StepBody"])]
    box = Table([[badge, text]], colWidths=[13 * mm, 145 * mm])
    box.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), colors.white),
        ("BOX", (0, 0), (-1, -1), 0.6, LINE),
        ("LEFTPADDING", (0, 0), (-1, -1), 8),
        ("RIGHTPADDING", (0, 0), (-1, -1), 8),
        ("TOPPADDING", (0, 0), (-1, -1), 7),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 7),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
    ]))
    return KeepTogether([box, Spacer(1, 3 * mm)])


def callout(title, body, color=GREEN):
    table = Table([[
        Paragraph(title, styles["Callout"]),
        Paragraph(body, styles["Smallx"]),
    ]], colWidths=[43 * mm, 115 * mm])
    table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), PALE),
        ("BOX", (0, 0), (-1, -1), 0.7, color),
        ("LINEBEFORE", (0, 0), (0, -1), 4, color),
        ("LEFTPADDING", (0, 0), (-1, -1), 9),
        ("RIGHTPADDING", (0, 0), (-1, -1), 9),
        ("TOPPADDING", (0, 0), (-1, -1), 9),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 9),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
    ]))
    return KeepTogether([table, Spacer(1, 4 * mm)])


def bullet(text):
    return Paragraph(f"<font color='#176A50'>&#9679;</font>&nbsp;&nbsp;{text}", styles["Bodyx"])


def access_table():
    rows = [
        ["Role", "Primary surface", "Main permissions", "Restricted actions"],
        ["Guest", "Mobile", "Browse landmarks and public information", "No saved data, badges, reviews, or redemption"],
        ["Tourist", "Mobile", "Commute, save, collect, review, remember, redeem", "No content or account administration"],
        ["Partner", "Mobile partner workspace", "Submit business, edit offer, scan QR, view reports", "No tourist badge earning or admin portal access"],
        ["Editor", "Web admin portal", "Maintain landmarks, routes, terminals, and content", "No account control, publication, deletion, or approval"],
        ["Admin", "Web admin portal", "Full governance, approval, publishing, analytics, invitations", "Cannot demote own account"],
    ]
    data = [[Paragraph(v, styles["TableHead"] if i == 0 else styles["TableCell"]) for v in row] for i, row in enumerate(rows)]
    table = Table(data, colWidths=[23 * mm, 35 * mm, 61 * mm, 49 * mm], repeatRows=1)
    table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), DARK_GREEN),
        ("BACKGROUND", (0, 1), (-1, -1), colors.white),
        ("BACKGROUND", (0, 2), (-1, 2), PALE),
        ("BACKGROUND", (0, 4), (-1, 4), PALE),
        ("GRID", (0, 0), (-1, -1), 0.45, LINE),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 6),
        ("RIGHTPADDING", (0, 0), (-1, -1), 6),
        ("TOPPADDING", (0, 0), (-1, -1), 7),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 7),
    ]))
    return table


def flow_row(items):
    cells = []
    widths = []
    for index, item in enumerate(items):
        cells.append(Paragraph(item, ParagraphStyle(
            f"flow{index}", parent=styles["Smallx"], fontName="Helvetica-Bold",
            fontSize=8, leading=10, alignment=TA_CENTER, textColor=DARK_GREEN,
        )))
        widths.append(32 * mm)
        if index < len(items) - 1:
            cells.append(Paragraph("&gt;", ParagraphStyle(
                f"arrow{index}", parent=styles["Bodyx"], fontName="Helvetica-Bold",
                fontSize=14, alignment=TA_CENTER, textColor=GOLD,
            )))
            widths.append(8 * mm)
    table = Table([cells], colWidths=widths)
    table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), colors.white),
        ("BOX", (0, 0), (-1, -1), 0.5, LINE),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("TOPPADDING", (0, 0), (-1, -1), 10),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 10),
        ("LEFTPADDING", (0, 0), (-1, -1), 4),
        ("RIGHTPADDING", (0, 0), (-1, -1), 4),
    ]))
    return KeepTogether([table, Spacer(1, 5 * mm)])


def build_pdf():
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    doc = BaseDocTemplate(
        str(OUTPUT), pagesize=A4,
        leftMargin=20 * mm, rightMargin=20 * mm,
        topMargin=20 * mm, bottomMargin=22 * mm,
        title="Cavite Explorer Role Workflows",
        author="Cavite Explorer Development Team",
        subject="Step-by-step operating guide for each Cavite Explorer role",
    )
    frame = Frame(doc.leftMargin, doc.bottomMargin, doc.width, doc.height, id="main")
    doc.addPageTemplates(PageTemplate(id="standard", frames=[frame], onPage=on_page))
    story = []

    # Cover
    story.extend([Spacer(1, 24 * mm)])
    if LOGO.exists():
        logo = Image(str(LOGO), width=40 * mm, height=40 * mm)
        logo.hAlign = "CENTER"
        story.extend([logo, Spacer(1, 11 * mm)])
    story.extend([
        Paragraph("OPERATIONS AND USER GUIDE", styles["CoverKicker"]),
        Paragraph("Cavite Explorer<br/>Role Workflows", styles["CoverTitle"]),
        Paragraph(
            "Step-by-step instructions for guests, tourists, partners, editors, and administrators.",
            styles["CoverSub"],
        ),
        Spacer(1, 19 * mm),
    ])
    cover_meta = Table([
        [Paragraph("Platform", styles["Smallx"]), Paragraph("Android mobile app + web admin portal", styles["Bodyx"])],
        [Paragraph("Production API", styles["Smallx"]), Paragraph("cavite-explorer-backend.onrender.com", styles["Bodyx"])],
        [Paragraph("Guide version", styles["Smallx"]), Paragraph("1.0 - August 2026", styles["Bodyx"])],
    ], colWidths=[35 * mm, 93 * mm])
    cover_meta.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#FFFFFF14")),
        ("BOX", (0, 0), (-1, -1), 0.6, colors.HexColor("#FFFFFF55")),
        ("GRID", (0, 0), (-1, -1), 0.3, colors.HexColor("#FFFFFF33")),
        ("TEXTCOLOR", (0, 0), (-1, -1), colors.white),
        ("LEFTPADDING", (0, 0), (-1, -1), 10),
        ("RIGHTPADDING", (0, 0), (-1, -1), 10),
        ("TOPPADDING", (0, 0), (-1, -1), 8),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
    ]))
    story.extend([cover_meta, PageBreak()])

    # Role map
    story.extend(role_header(
        "Start here", "Roles and access boundaries",
        "Use the role assigned in the database. Interface visibility is helpful, but the backend remains the final permission authority.",
    ))
    story.extend([access_table(), Spacer(1, 6 * mm)])
    story.append(Paragraph("Account lifecycle", styles["H2x"]))
    story.append(flow_row(["Admin sends invite", "Recipient sets password", "Role-specific sign-in", "Backend checks role and status"]))
    story.append(callout(
        "Important boundary",
        "Admins and editors sign in to the web portal. Partners sign in to the Android app. Tourists use the standard mobile experience. A disabled account must be rejected even if an old session is stored on the device.",
    ))
    story.extend([
        bullet("Administrator invitations expire after seven days and should be sent only to verified email addresses."),
        bullet("Partners become publicly visible only after their business application is approved."),
        bullet("An administrator cannot change their own role; another administrator must perform that action."),
        PageBreak(),
    ])

    # Guest
    story.extend(role_header(
        "Role 1", "Guest visitor",
        "A guest can explore public tourism information before creating an account. Account-bound features stay unavailable.",
    ))
    story.extend([
        step(1, "Open the Android app", "Wait for the home screen to load published landmarks from the production API."),
        step(2, "Allow foreground location when useful", "Location improves distance labels and nearby ordering. A guest may decline and still browse public content."),
        step(3, "Search or filter", "Search by landmark, barangay, or municipality. Pull down on Home to refresh landmarks, rankings, user state, and current location."),
        step(4, "Open a landmark", "Review the overview, history, plan-your-visit details, reminders, community stories, and participating badge partners."),
        step(5, "Choose the next action", "Use driving directions for private-car navigation. Sign in before saving places, starting account-based commute sessions, earning badges, reviewing, or redeeming rewards."),
        callout("When sign-in is required", "The app should explain the restricted feature and route the guest to authentication. It must not begin background badge tracking for guests."),
        Paragraph("Guest completion check", styles["H2x"]),
        bullet("Published landmark photos and information load correctly."),
        bullet("Location denial does not crash or block ordinary browsing."),
        bullet("Restricted actions request sign-in instead of silently failing."),
        PageBreak(),
    ])

    # Tourist commute
    story.extend(role_header(
        "Role 2A", "Tourist: discover and commute",
        "Registered tourists receive the full mobile experience, including verified route choices and live location guidance.",
    ))
    story.extend([
        step(1, "Sign in", "Use email/password or the configured Google authentication flow. Complete the profile if prompted."),
        step(2, "Prepare permissions", "Grant precise location and notifications. For background commute and badge behavior, grant the Android background-location permission requested by the app."),
        step(3, "Find a destination", "Use Home rankings, nearest results, filters, the map, or saved landmarks. Open the landmark and review visit information."),
        step(4, "Compare commute choices", "Review fare, walking distance, rides, signboards, and transfers. Select the efficient option that matches the desired cost/convenience tradeoff."),
        step(5, "Start Commute", "The guide begins from the current location and uses administrator-verified transport routes. Jeepneys may be boarded at a suitable point along their verified route; tricycles are boarded only at their pinned terminal."),
        step(6, "Follow the live map", "Keep location enabled. The instruction card stays at the top, passed geometry turns gray, and steps advance automatically when the user reaches or joins the next verified segment."),
        step(7, "Handle transfers", "Follow the displayed get-off point, walk connector, next signboard, and vehicle icon. If the user joins the next route before the exact previous endpoint, the guide may advance based on route proximity and movement."),
        step(8, "Arrive", "At the landmark, live commute ends and badge visit verification can continue without requiring the user to stay on the commute screen."),
        callout("Route truth rule", "The verified route database determines available public-transport movement. AI improves wording and presentation; it must not invent an unverified vehicle route."),
        PageBreak(),
    ])

    # Tourist badge/reviews
    story.extend(role_header(
        "Role 2B", "Tourist: badges, memories, and rewards",
        "Badges reward verified time at a landmark and unlock partner discounts and community participation.",
    ))
    story.extend([
        step(1, "Enter the verification radius", "The app recognizes the landmark area and starts or resumes its independent visit countdown."),
        step(2, "Remain at the landmark", "Keep location enabled. The countdown continues while navigating other app pages and while the Android app remains active in the background."),
        step(3, "Return during the grace period", "Leaving pauses progress and starts the five-minute return window. Returning in time preserves accumulated visit time; otherwise the visit resets."),
        step(4, "Unlock the badge", "After the configured visit time, the app displays the badge-unlocked experience and adds the unique badge to the collection. The same landmark badge cannot be earned twice."),
        step(5, "Share a verified review", "From Visited Places or the landmark Community tab, add a rating, thoughts, and photos. Photos open in a swipeable full-screen gallery. Community previews show two reviews; See all opens the complete list."),
        step(6, "Save a personal memory", "Use the memory lane to record a date, mood, story, favorite moment, rating, and photos. Keep it private or share it publicly."),
        step(7, "Use the badge QR", "Open the collected badge, view partners within the reward area, and present its unique QR to an eligible partner."),
        step(8, "Confirm redemption", "A successful scan marks that partner as claimed for this badge. The same partner cannot redeem the same user's badge twice."),
        callout("Multiple nearby landmarks", "Each eligible landmark visit is tracked independently. Already-earned landmarks do not restart badge notifications or create duplicate badges."),
        PageBreak(),
    ])

    # Partner onboarding
    story.extend(role_header(
        "Role 3A", "Partner: invitation and onboarding",
        "A partner account is created only through an administrator invitation and is used only in the mobile app.",
    ))
    story.extend([
        step(1, "Administrator sends the invitation", "The admin enters the partner's email, selects Partner - mobile only, and sends the secure seven-day link."),
        step(2, "Open the email on Android", "Tap Open secure invitation on the phone where Cavite Explorer is installed. If the app is not available, use the web bridge and then reopen the deep link."),
        step(3, "Create the password", "Confirm the invited email, enter matching passwords, and create the partner account. The app signs in the new partner automatically."),
        step(4, "Pin the business location", "Search or place the pin precisely at the storefront. Confirm the automatically suggested city/municipality and barangay, correcting them when necessary."),
        step(5, "Enter business information", "Provide business name, category, address, contact number, opening and closing times, and a useful public description."),
        step(6, "Upload the logo", "Crop and position the complete logo inside the circular preview. Confirm it remains readable at small sizes."),
        step(7, "Propose the discount", "Enter the offer title, discount label, and conditions. Eligible landmark badges within 2.5 km are determined from the pinned business location."),
        step(8, "Submit for approval", "Review all details and submit. The application remains non-public until an administrator approves it."),
        callout("No self-registration", "Partners cannot create an ordinary account and promote it to partner. The admin invitation establishes the controlled partner identity."),
        PageBreak(),
    ])

    # Partner operations
    story.extend(role_header(
        "Role 3B", "Partner: daily operation and redemption",
        "Approved partners use the dashboard to maintain their offer, scan badges, and review redemption activity.",
    ))
    story.extend([
        step(1, "Open the partner dashboard", "Sign in using the invited partner account. Verify the approved business, logo, address, current offer, and dashboard counts."),
        step(2, "Update the offer when needed", "Use Edit to change the offer title, discount label, or conditions. Keep conditions short enough for tourists and staff to understand."),
        step(3, "Ask the tourist to open the badge", "The tourist selects a collected badge and opens its QR side. Confirm that your business appears in the eligible partner list."),
        step(4, "Start Scan QR", "Grant camera permission and center the complete QR inside the scanner frame. For emulator testing, use a real second display or camera-injected test image; production staff should use a real device."),
        step(5, "Pass eligibility checks", "The backend validates the partner account, approval state, badge ownership, eligible landmark distance, scan location, and prior redemption."),
        step(6, "Apply the discount", "Only provide the stated discount after the app confirms success. If declined, read the reason rather than overriding it manually."),
        step(7, "Review reports", "Use redemption history and date-range reports to reconcile scans. Pull down to refresh current dashboard data."),
        callout("One claim per partner", "A tourist can redeem a particular earned badge once at each eligible partner. A repeat scan at the same partner must be declined, even if other nearby partners remain available."),
        Paragraph("Common decline reasons", styles["H2x"]),
        bullet("Badge QR is invalid or does not belong to an earned badge."),
        bullet("Partner is not approved or is outside the badge landmark's 2.5 km reward area."),
        bullet("Location is unavailable or the scan is outside the allowed operating area."),
        PageBreak(),
    ])

    # Editor
    story.extend(role_header(
        "Role 4", "Editor: verified content maintenance",
        "Editors improve tourism and transport data without receiving account-control or final governance permissions.",
    ))
    story.extend([
        step(1, "Sign in to the web portal", "Use the editor invitation account. Accounts should not appear in editor navigation, while content sections remain available."),
        step(2, "Create or update a landmark", "Use the map search and pin, confirm municipality/barangay, complete essential information, visitor information, history, reminders, photos, and badge design."),
        step(3, "Check location accuracy", "Zoom in and place the pin on the actual landmark access point. Verify coordinates, street details, image order, and visitor-facing text."),
        step(4, "Maintain transport routes", "Set terminals A/B, municipalities, road names, direction, vehicle type, signboards, fares, and exact route geometry. Add boarding/transfer access where commuters can realistically connect."),
        step(5, "Maintain tricycle coverage", "Pin the terminal, configure its service radius and hours, and draw only missing road connectors when normal road routing cannot reach a legitimate road."),
        step(6, "Verify freshness", "Review stale-route reminders, recheck local operations, correct the route, and update its verification date."),
        step(7, "Save for administrator review", "Editors may create and update content, but final publishing, archiving, deletion, partner approval, and account changes remain administrator actions."),
        callout("Data-quality rule", "Guide points shape geometry only; they are not road names. Road markers label verified segments. Directional route geometry should represent the actual vehicle path, not a straight line between terminals."),
        Paragraph("Editor checklist before handoff", styles["H2x"]),
        bullet("Names, barangay, municipality, coordinates, and source information are complete."),
        bullet("Photos have permission for use and display correctly after upload."),
        bullet("Signboards, vehicle type, direction, fare basis, transfers, and walk limits are realistic."),
        PageBreak(),
    ])

    # Admin
    story.extend(role_header(
        "Role 5", "Administrator: governance and operations",
        "Administrators control privileged access, final publication, partner approval, analytics, and operational quality.",
    ))
    story.extend([
        step(1, "Review the overview", "Check system status, analytics, visitor activity, badge claims, route coverage, partner activity, and stale-data alerts."),
        step(2, "Manage accounts", "Search and filter accounts, assign user/editor/admin roles, and enable or disable access. Never disable the last working administrator."),
        step(3, "Invite team members", "Enter the verified email, choose Editor, Admin, or Partner, and send the secure link. Confirm delivery through Brevo and never share invite tokens publicly."),
        step(4, "Review content", "Inspect landmark information, map pins, photos, badge rules, routes, fares, transfers, and verification dates before publication."),
        step(5, "Publish, archive, or delete", "Publish only verified records. Archive information that should disappear without losing history. Delete carefully because related trips or records may require preservation."),
        step(6, "Approve partner applications", "Verify identity, location, business details, logo, operating hours, proposed offer, and eligible landmarks. Approve or reject with a clear reason."),
        step(7, "Monitor reward activity", "Review partner and redemption analytics for repeated failures, suspicious scan volume, location anomalies, and expired offers."),
        step(8, "Maintain production services", "Monitor Render health, Neon data, Cloudinary storage, Brevo delivery, authentication callbacks, Groq availability, and OSM usage."),
        callout("Self-role protection", "The logged-in administrator cannot change their own role. Use another verified administrator so an accidental self-demotion cannot lock the team out."),
        PageBreak(),
    ])

    # Operations and field test
    story.extend(role_header(
        "Release operations", "Support, security, and field-test checklist",
        "Use this checklist before distributing a new APK or declaring a production update complete.",
    ))
    story.append(Paragraph("Android release test", styles["H2x"]))
    for item in [
        "Install the signed release APK on a real Android phone and confirm it uses the public HTTPS backend, not localhost or 10.0.2.2.",
        "Test first launch, manual login, Google login, forgot password, partner deep links, and session persistence.",
        "Grant precise and background location, notifications, camera, and photo access; repeat one scenario after denying each permission.",
        "Test search, pull-to-refresh, saved landmarks, photo upload/viewer, community review limits, and the full reviews page.",
        "Walk or simulate an actual commute and verify route joining, transfers, gray completed geometry, automatic steps, and arrival.",
        "Enter and leave a badge radius, background the app, return inside the grace period, unlock the badge, and verify local notifications.",
        "Scan a badge at an approved partner, then scan again and confirm the second attempt is declined.",
    ]:
        story.append(bullet(item))

    story.append(Paragraph("Operational response", styles["H2x"]))
    response_rows = [
        ["Symptom", "First check", "Owner"],
        ["App loads slowly", "Open /health; a free Render service may be waking", "Admin/operator"],
        ["Images fail", "Cloudinary configuration and stored image URL", "Admin/operator"],
        ["Invite not delivered", "Brevo sender, API key, IP authorization, spam filter", "Admin/operator"],
        ["Invalid callback", "Exact Neon trusted domain and configured redirect URL", "Admin/operator"],
        ["Route is wrong", "Verified geometry, direction, access points, and freshness", "Editor/admin"],
        ["Badge does not progress", "Precise/background location, radius, active account", "Tourist support"],
        ["QR declined", "Approval, distance, ownership, prior redemption", "Partner/admin"],
    ]
    data = [[Paragraph(v, styles["TableHead"] if i == 0 else styles["TableCell"]) for v in row] for i, row in enumerate(response_rows)]
    table = Table(data, colWidths=[42 * mm, 89 * mm, 37 * mm], repeatRows=1)
    table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), DARK_GREEN),
        ("BACKGROUND", (0, 1), (-1, -1), colors.white),
        ("GRID", (0, 0), (-1, -1), 0.45, LINE),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 6),
        ("RIGHTPADDING", (0, 0), (-1, -1), 6),
        ("TOPPADDING", (0, 0), (-1, -1), 6),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
    ]))
    story.extend([table, Spacer(1, 5 * mm)])
    story.append(callout(
        "Protect production access",
        "Never place .env files, API keys, database URLs, keystores, key.properties, or passwords in GitHub, screenshots, PDFs, issue reports, or chat messages. Keep the Android signing key backed up securely; future updates must use the same key.",
        color=ORANGE,
    ))
    story.append(Paragraph(
        "Repository: github.com/mirasol25/caviteExplorerTouristGuide", styles["Smallx"]
    ))

    doc.build(story)
    print(OUTPUT)


if __name__ == "__main__":
    build_pdf()
