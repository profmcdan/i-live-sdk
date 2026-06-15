import os
from reportlab.lib.pagesizes import letter
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, KeepTogether, Image
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_RIGHT, TA_JUSTIFY
from reportlab.lib.colors import HexColor

def draw_cover_page(canvas, doc):
    canvas.saveState()
    # Background color - Dark Obsidian Navy
    canvas.setFillColor(HexColor("#0F121A"))
    canvas.rect(0, 0, doc.pagesize[0], doc.pagesize[1], stroke=0, fill=1)
    
    # Left decorative green vertical strip (Branding color)
    canvas.setFillColor(HexColor("#00E676"))
    canvas.rect(0, 0, 15, doc.pagesize[1], stroke=0, fill=1)
    
    # Top geometric light accent
    canvas.setFillColor(HexColor("#171B26"))
    canvas.rect(15, doc.pagesize[1] - 250, doc.pagesize[0] - 15, 250, stroke=0, fill=1)
    
    # Draw a subtle diagonal branding accent line
    canvas.setStrokeColor(HexColor("#00E676"))
    canvas.setLineWidth(1)
    canvas.line(15, doc.pagesize[1] - 250, doc.pagesize[0], doc.pagesize[1] - 150)
    
    canvas.restoreState()

def draw_later_pages(canvas, doc):
    canvas.saveState()
    # Top primary color accent line
    canvas.setFillColor(HexColor("#0D47A1"))
    canvas.rect(0, doc.pagesize[1] - 6, doc.pagesize[0], 6, stroke=0, fill=1)
    
    # Left decorative light gray vertical border
    canvas.setFillColor(HexColor("#E2E8F0"))
    canvas.rect(0, 0, 8, doc.pagesize[1], stroke=0, fill=1)
    
    # Draw Footer
    canvas.setFont('Helvetica', 8)
    canvas.setFillColor(HexColor("#64748B"))
    canvas.drawString(54, 30, "FaceGuard: Enterprise Biometric Liveness & Verification SDK")
    canvas.drawRightString(doc.pagesize[0] - 54, 30, f"Page {doc.page}")
    canvas.restoreState()

def generate_pdf(filename):
    # Setup document
    doc = SimpleDocTemplate(
        filename,
        pagesize=letter,
        leftMargin=54, # 0.75 in
        rightMargin=54,
        topMargin=54,
        bottomMargin=54
    )
    
    styles = getSampleStyleSheet()
    
    # Define custom colors
    c_primary = HexColor("#0D47A1")  # Banking Navy
    c_accent_green = HexColor("#00E676") # Success Green
    c_accent_dark = HexColor("#0F121A") # Obsidian
    c_text_dark = HexColor("#1E293B") # Charcoal Slate
    c_text_light = HexColor("#F8FAFC") # Off-white
    c_muted = HexColor("#64748B") # Gray slate
    
    # Custom Paragraph Styles
    style_cover_title = ParagraphStyle(
        name='CoverTitle',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=36,
        leading=44,
        textColor=colors.white,
        spaceAfter=15
    )
    
    style_cover_subtitle = ParagraphStyle(
        name='CoverSubtitle',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=18,
        leading=24,
        textColor=c_accent_green,
        spaceAfter=30
    )
    
    style_cover_pitch = ParagraphStyle(
        name='CoverPitch',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=12,
        leading=18,
        textColor=HexColor("#CBD5E1"),
        spaceAfter=120
    )
    
    style_cover_meta = ParagraphStyle(
        name='CoverMeta',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=10,
        leading=14,
        textColor=c_muted
    )
    
    style_h1 = ParagraphStyle(
        name='CustomH1',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=20,
        leading=26,
        textColor=c_primary,
        spaceBefore=15,
        spaceAfter=12,
        keepWithNext=True
    )
    
    style_h2 = ParagraphStyle(
        name='CustomH2',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=13,
        leading=18,
        textColor=c_accent_dark,
        spaceBefore=10,
        spaceAfter=8,
        keepWithNext=True
    )

    style_body = ParagraphStyle(
        name='CustomBody',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=10,
        leading=15,
        textColor=c_text_dark,
        spaceAfter=10
    )
    
    style_body_bold = ParagraphStyle(
        name='CustomBodyBold',
        parent=style_body,
        fontName='Helvetica-Bold'
    )

    style_bullet = ParagraphStyle(
        name='CustomBullet',
        parent=style_body,
        leftIndent=15,
        firstLineIndent=-10,
        spaceAfter=6
    )
    
    style_table_header = ParagraphStyle(
        name='TableHeader',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=9,
        leading=12,
        textColor=colors.white
    )
    
    style_table_cell = ParagraphStyle(
        name='TableCell',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=8.5,
        leading=11.5,
        textColor=c_text_dark
    )
    
    story = []
    
    # ----------------------------------------------------
    # COVER PAGE CONTENT (Starts in a Dark Mode block)
    # ----------------------------------------------------
    story.append(Spacer(1, 100))
    story.append(Paragraph("FACEGUARD", style_cover_title))
    story.append(Paragraph("Enterprise Biometric Liveness & Verification SDK", style_cover_subtitle))
    story.append(Spacer(1, 10))
    story.append(Paragraph(
        "A developer-first, defense-grade biometric identity assurance suite. Enforce real-time physical presence verification, mitigate injection/spoofing vectors, and automate KYC/AML onboarding compliance via deep-learning edge tracking and server-side cryptographic audit trails.",
        style_cover_pitch
    ))
    story.append(Spacer(1, 80))
    
    meta_text = """
    <b>Product Brief & Developer Overview</b><br/>
    <b>Owner:</b> Crokta Engineering<br/>
    <b>Version:</b> 1.1.0 (Release Dec 2023)<br/>
    <b>SDK Capability:</b> Google ML Kit (Passive/Active), AWS Rekognition Integration
    """
    story.append(Paragraph(meta_text, style_cover_meta))
    story.append(PageBreak())
    
    # ----------------------------------------------------
    # PAGE 2: EXECUTIVE SUMMARY & CRITICAL PROBLEM
    # ----------------------------------------------------
    story.append(Paragraph("Executive Product Summary", style_h1))
    story.append(Spacer(1, 5))
    
    story.append(Paragraph(
        "Digital identity verification faces an unprecedented threat environment. Sophisticated presentation attacks—ranging from high-resolution digital screen replays and 3D facial masks to virtual camera injections—easily bypass standard static image uploads, creating catastrophic compliance vulnerabilities.",
        style_body
    ))
    
    story.append(Paragraph(
        "<b>FaceGuard</b> is an enterprise-grade biometric liveness verification solution designed to establish absolute cryptographic trust in remote customer identification. Engineered for low latency and high accuracy, FaceGuard operates at the critical intersection of on-device neural processing and server-side verification, providing instant, tamper-proof identity assurance.",
        style_body
    ))
    
    story.append(Paragraph("Core Value Propositions", style_h2))
    
    story.append(Paragraph(
        "• <b>Advanced Multi-Modal Liveness:</b> Utilizes a highly robust, randomized gesture validation matrix (eye blink detection, warmth-based smile classification, horizontal yaw tracking, and vertical pitch analysis) processed on-device via Google ML Kit's neural networks. Randomized active challenge sequences completely defeat pre-recorded replay attempts.",
        style_bullet
    ))
    story.append(Paragraph(
        "• <b>Channel-Segmented Onboarding:</b> Organize verification flows using custom segmentation (e.g. Business vs Personal channels). Implements atomic database constraints on BVN and channel pairs, preventing duplicate accounts while permitting seamless, clean retries for failed attempts.",
        style_bullet
    ))
    story.append(Paragraph(
        "• <b>Cryptographic Session Isolation:</b> Features strict zero-seeding client-side credentials. All API calls are validated against SHA-256 key hashes stored in the backend database. Masked keys prevent exposure in logs or dashboards, maintaining a zero-trust architecture.",
        style_bullet
    ))
    story.append(Paragraph(
        "• <b>Pre-Signed Replay Audits:</b> Automatically records a high-definition 5.0-second video of the verification session, stored in private, access-controlled AWS S3 buckets. Compliance officers can review sessions via time-locked pre-signed URLs directly in the admin dashboard.",
        style_bullet
    ))
    
    story.append(PageBreak())
    
    # ----------------------------------------------------
    # PAGE 3: INTEGRATION USE CASES & SDK TESTING PANEL
    # ----------------------------------------------------
    left_cell_flowables = [
        Paragraph("Integration Use Cases", style_h1),
        Spacer(1, 5),
        Paragraph(
            "FaceGuard is engineered to secure the most critical client interactions across digital banking, fintech portals, and high-trust enterprise applications. By embedding defense-grade face liveness checks at high-risk touchpoints, organizations can eliminate identity fraud and spoofing vectors while maintaining frictionless user conversion rates.",
            style_body
        ),
        Spacer(1, 5),
        Paragraph(
            "• <b>Onboarding (New Registration):</b> Run liveness audit checks before registering a new user profile. Ensures that the individual creating the account is physically present and is not a synthetic identity or pre-recorded video stream, directly safeguarding the KYC entry point.",
            style_bullet
        ),
        Paragraph(
            "• <b>Account Face Verification:</b> Compare current face live capture against your registered onboarding face profile. Replaces or reinforces traditional passwords during login and high-importance session changes, preventing unauthorized account takeover and credential stuffing.",
            style_bullet
        ),
        Paragraph(
            "• <b>Reset Transaction PIN:</b> Require passive facial audit prior to granting secure PIN updates. Protects critical user credentials from unauthorized resets by forcing a biometric verification loop before changing security PINs.",
            style_bullet
        ),
        Paragraph(
            "• <b>High-Value Transfer:</b> Initiate step-up verification before transferring funds above limit. Acts as an automated step-up liveness check triggered dynamically when user transactions exceed risk or monetary thresholds, ensuring true account owner authorization.",
            style_bullet
        ),
        Spacer(1, 10),
        Paragraph("SDK Testing & Sandbox Panel", style_h2),
        Spacer(1, 4),
        Paragraph(
            "To streamline development, the FaceGuard companion application contains a built-in testing panel enabling developers to run instant integration sandboxing. Configure custom User IDs for auditing, adjust the target SDK API URL endpoints dynamically, and supply cryptographic API keys (X-API-Key) to validate authenticated liveness sessions instantly.",
            style_body
        )
    ]
    
    screenshot_path = "/Users/danielale/.gemini/antigravity-ide/brain/b30c823e-bde5-457a-9ee0-778740f711e1/media__1781504860437.png"
    if os.path.exists(screenshot_path):
        img_flowable = Image(screenshot_path, width=135, height=292) # 135 width, height = 135 * 1024 / 474 = 292
    else:
        img_flowable = Paragraph("<b>[Companion App Screenshot]</b><br/>Image file not found at path.", style_body)
        
    right_cell_flowables = [
        Spacer(1, 15),
        img_flowable
    ]
    
    # Dual column layout: left col 325pt, right col 155pt (total 480pt of 504pt printable area)
    page3_table = Table([[left_cell_flowables, right_cell_flowables]], colWidths=[325, 155])
    page3_table.setStyle(TableStyle([
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
        ('LEFTPADDING', (0,0), (-1,-1), 0),
        ('RIGHTPADDING', (0,0), (-1,-1), 0),
        ('BOTTOMPADDING', (0,0), (-1,-1), 0),
        ('TOPPADDING', (0,0), (-1,-1), 0),
    ]))
    
    story.append(page3_table)
    
    story.append(PageBreak())
    
    # ----------------------------------------------------
    # PAGE 4: ARCHITECTURE & TECHNICAL WORKFLOW
    # ----------------------------------------------------
    story.append(Paragraph("Product Architecture & Workflow", style_h1))
    story.append(Spacer(1, 5))
    
    story.append(Paragraph(
        "FaceGuard leverages a hybrid architecture designed to optimize both user experience and cryptographic security. The verification flow operates as follows:",
        style_body
    ))
    
    # Table showing steps
    table_data = [
        [
            Paragraph("Phase", style_table_header),
            Paragraph("Component & Technologies", style_table_header),
            Paragraph("Action & Security Benefit", style_table_header)
        ],
        [
            Paragraph("1. Session Init", style_table_cell),
            Paragraph("FastAPI Backend / Postgres DB", style_table_cell),
            Paragraph("Client requests verification. Backend performs SHA-256 hash comparison on API credentials and generates a secure session UUID.", style_table_cell)
        ],
        [
            Paragraph("2. Edge AI Tracking", style_table_cell),
            Paragraph("Flutter Client SDK / ML Kit", style_table_cell),
            Paragraph("Front-camera streams frames directly to on-device ML Kit neural networks, evaluating active user gestures (blinks, turns, tilts).", style_table_cell)
        ],
        [
            Paragraph("3. Video Capture", style_table_cell),
            Paragraph("Flutter Client / Camera API", style_table_cell),
            Paragraph("Immediately records a 5.0-second verification video clip, capturing physical presence and verifying session integrity.", style_table_cell)
        ],
        [
            Paragraph("4. Secure Upload", style_table_cell),
            Paragraph("Multipart API / AWS S3", style_table_cell),
            Paragraph("Video is securely uploaded via multipart POST request to access-controlled private AWS S3 buckets, shielding raw files from public URLs.", style_table_cell)
        ],
        [
            Paragraph("5. Biometric Match", style_table_cell),
            Paragraph("AWS Rekognition / Comparison", style_table_cell),
            Paragraph("Compares captured frame against stored onboarding reference image to compute facial match similarity and confidence scores.", style_table_cell)
        ]
    ]
    
    col_widths = [80, 140, 280]
    t = Table(table_data, colWidths=col_widths)
    t.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), c_primary),
        ('ALIGN', (0,0), (-1,-1), 'LEFT'),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
        ('BOTTOMPADDING', (0,0), (-1,0), 6),
        ('TOPPADDING', (0,0), (-1,0), 6),
        ('GRID', (0,0), (-1,-1), 0.5, HexColor("#CBD5E1")),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, HexColor("#F8FAFC")]),
        ('BOTTOMPADDING', (0,1), (-1,-1), 8),
        ('TOPPADDING', (0,1), (-1,-1), 8),
    ]))
    
    story.append(t)
    story.append(Spacer(1, 15))
    
    # ----------------------------------------------------
    # DEVELOPER-FIRST INTEGRATION (Moved to Page 3)
    # ----------------------------------------------------
    story.append(Paragraph("Developer-First Integration", style_h1))
    story.append(Spacer(1, 5))
    
    story.append(Paragraph(
        "FaceGuard is engineered to eliminate integration complexity. A fully functional companion sample application is included to serve as a complete reference guide, demonstrating liveness triggers, custom workflows, error handling, and API authorizations. A few lines of code are all it takes to initialize and start capturing secure biometric audits in your client application:",
        style_body
    ))
    
    # Dart code snippet container
    code_text = """
    <b>// Flutter Client SDK Initialization & Verification</b><br/>
    await LivenessSDK.initialize(<br/>
    &nbsp;&nbsp;backendUrl: 'https://api.crokta.com',<br/>
    &nbsp;&nbsp;environment: LivenessEnvironment.production,<br/>
    &nbsp;&nbsp;apiKey: 'sk_live_55a2...'<br/>
    );<br/>
    <br/>
    LivenessResult result = await LivenessSDK.verify(<br/>
    &nbsp;&nbsp;context,<br/>
    &nbsp;&nbsp;userId: 'customer_9901',<br/>
    &nbsp;&nbsp;verificationType: 'VERIFICATION',<br/>
    &nbsp;&nbsp;channel: 'personal'<br/>
    );<br/>
    <br/>
    if (result.success) {<br/>
    &nbsp;&nbsp;<b>// Secure token issued, route user to transaction</b><br/>
    }
    """
    
    t_code = Table([[Paragraph(code_text, ParagraphStyle(
        name='CodeStyle',
        parent=styles['Normal'],
        fontName='Courier',
        fontSize=8.5,
        leading=12,
        textColor=HexColor("#F8FAFC")
    ))]], colWidths=[500])
    t_code.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), HexColor("#0F121A")),
        ('PADDING', (0,0), (-1,-1), 12),
        ('GRID', (0,0), (-1,-1), 1, HexColor("#1E293B")),
    ]))
    
    story.append(t_code)
    
    story.append(PageBreak())
    
    # ----------------------------------------------------
    # PAGE 5: SECURITY ANALYTICS & DASHBOARD (EXPANDED)
    # ----------------------------------------------------
    story.append(Paragraph("Security Analytics & Dashboard", style_h1))
    story.append(Spacer(1, 5))
    
    story.append(Paragraph(
        "All biometric verification sessions are logged in a premium, glassmorphic ReactJS admin console, providing compliance officers and security teams with complete operational visibility. The dashboard enables instant audits by User ID, BVN, or Session ID, displaying key telemetry indicators including device hardware model, platform OS version, client IP address, and geographic coordinate anchors (latitude/longitude) to trace anomalous location access.",
        style_body
    ))
    story.append(Paragraph(
        "For compliance verification, the console fetches a secure, pre-signed S3 video replay player modal to review the recorded 5.0-second user session. The interface shows detailed face comparison metrics, including match/mismatch status, percentage similarity scores, and verification types (Onboarding vs Verification). Real-time analytics charts visualize pass/fail ratios, channel segmentation metrics (Personal vs Business traffic), and overall transaction success rates, facilitating proactive detection of distributed identity fraud patterns.",
        style_body
    ))
    story.append(Paragraph(
        "<b>Predictive Threat Intelligence & Biometric Search</b>: Built-in fraud detection algorithms analyze timing signatures and telemetry correlation models. The system flags device duplication (multiple BVN verifications from a single hardware signature) and velocity anomalies (rapid location hops), firing real-time webhook payloads to alert platform security services. In addition, security teams can perform biometrically indexed reverse facial searches across the customer reference database to detect synthetic account-takeover or identity manipulation rings, making FaceGuard a comprehensive security shield.",
        style_body
    ))
    
    story.append(Spacer(1, 15))
    
    story.append(Paragraph("Business ROI & Strategic Benefits", style_h1))
    story.append(Spacer(1, 5))
    
    story.append(Paragraph(
        "• <b>99.4% Anti-Spoofing Accuracy:</b> Trained on millions of variations, our edge neural networks instantly classify and reject synthetic media, paper cutouts, and screen displays.",
        style_bullet
    ))
    story.append(Paragraph(
        "• <b>Regulatory KYC/AML Alignment:</b> Exceeds strict central banking compliance standards by maintaining full, auditable video logs of every liveness transaction, complete with client telemetry (device OS version, IP geolocation, and time anchors).",
        style_bullet
    ))
    story.append(Paragraph(
        "• <b>Frictionless Conversion Optimization:</b> Completes full biometric tracking and verification in under 5.0 seconds. Zero-jank execution keeps registration funnel conversion rates exceptionally high.",
        style_bullet
    ))
    story.append(Paragraph(
        "• <b>Flexible Integration Models:</b> Supports direct AWS Cognito/Amplify streaming pools, custom AWS Rekognition pipelines, or offline mock verification modes for internal sandbox runs.",
        style_bullet
    ))
    
    story.append(Spacer(1, 20))
    
    # Call to action block
    cta_style_title = ParagraphStyle(
        name='CTATitle',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=12,
        leading=16,
        textColor=colors.white,
        alignment=TA_CENTER
    )
    cta_style_body = ParagraphStyle(
        name='CTABody',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=9.5,
        leading=14,
        textColor=HexColor("#CBD5E1"),
        alignment=TA_CENTER
    )
    
    cta_content = [
        [Paragraph("Ready to secure your customer identity pipeline?", cta_style_title)],
        [Spacer(1, 5)],
        [Paragraph("Contact our engineering team to request sandbox access, customize liveness thresholds, or coordinate a trial deploy.", cta_style_body)],
        [Spacer(1, 6)],
        [Paragraph("<b>Email:</b> info@crokta.com | <b>Website:</b> www.crokta.com", cta_style_title)]
    ]
    
    t_cta = Table(cta_content, colWidths=[460])
    t_cta.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), HexColor("#0D47A1")),
        ('PADDING', (0,0), (-1,-1), 16),
        ('ALIGN', (0,0), (-1,-1), 'CENTER'),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('GRID', (0,0), (-1,-1), 1.5, HexColor("#00E676")),
    ]))
    
    story.append(t_cta)
    
    # Build Document
    doc.build(story, onFirstPage=draw_cover_page, onLaterPages=draw_later_pages)

if __name__ == "__main__":
    pdf_path = "../docs/FaceGuard_Product_Brief.pdf"
    os.makedirs(os.path.dirname(pdf_path), exist_ok=True)
    generate_pdf(pdf_path)
    print(f"Success! PDF generated and saved to: {pdf_path}")
