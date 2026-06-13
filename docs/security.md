# Security & Compliance Specification

This document details CST Group security policies, data guidelines, and anti-tamper mechanisms implemented for biometric liveness verification.

---

## 1. Data Protection & Privacy Compliance
The system conforms with the **Nigeria Data Protection Act (NDPA)**, **GDPR**, and **CBN Data Protection Guidelines**:

* **Zero-Retention Device Policy**: Video frames and audit files captured during session recording are deleted from the device filesystem immediately after verify calls complete. No image or video metadata persists locally on user devices.
* **Ephemeral Sessions**: Sessions created with AWS Rekognition/Mock provider expire automatically after 5 minutes.
* **Audit Storage**: Production S3 audit buckets should enforce AES-256 server-side encryption and strict IAM read/write permissions.

---

## 2. Network & Transport Security
* **TLS 1.3 Requirements**: All server-to-client and server-to-provider interactions must be encrypted over TLS 1.3 (HTTPS).
* **API Authentication**: Endpoint access requires validation using an API token header (`X-API-Key`) configuration.

---

## 3. Anti-Tampering & Device Intelligence
The SDK and backend capture device integrity metrics to prevent API spoofing and synthetic attacks:

* **Telemetry Log Audits**: Mobile devices report system signatures (OS details, client IP address, Lagos-HQ default geographic coordinates) to backend endpoints. In production, these should be fed directly into an automated fraud engine to detect abnormal request patterns.
* **Root/Jailbreak Prevention**: Downstream application developers should integrate security guard plugins (such as `flutter_jailbreak_detection`) to block SDK execution on rooted Android, jailbroken iOS, or emulated environments if high security settings are flagged.
