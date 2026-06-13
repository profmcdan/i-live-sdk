# AWS Rekognition Face Liveness Setup Guide

This guide describes how to configure AWS Rekognition Face Liveness and IAM resources in the AWS Console to run liveness verifications in production or staging.

---

## Step 1: Create an S3 Bucket (For Audit Images)
AWS Rekognition uploads the reference image (the face cutout used to evaluate liveness) and diagnostic session logs to an S3 bucket you provide.

1. Open the **Amazon S3 Console**.
2. Click **Create bucket**.
3. Enter a unique bucket name (e.g., `kolomoni-liveness-audit`).
4. Select the target region (e.g., `us-east-1`).
5. Keep **Block all public access** enabled to preserve security.
6. Enable **Bucket Key** under Encryption settings to reduce KMS costs.
7. Click **Create bucket**.

### Configure Lifecycle Rules (Compliance & Privacy)
To comply with NDPA/GDPR zero-retention guidelines, configure S3 to delete old audit images automatically:
1. Open your S3 bucket, click the **Management** tab.
2. Click **Create lifecycle rule**.
3. Rule name: `DeleteAuditImagesAfter30Days`.
4. Choose **Apply to all objects in the bucket** (and acknowledge the warning checkbox).
5. Check **Expire current versions of objects**.
6. Under *Days after object creation*, enter `30`.
7. Click **Create rule**.

---

## Step 2: Configure IAM Permissions
You must grant your FastAPI Backend API credentials to create liveness sessions and retrieve verification outcomes.

1. Open the **IAM Console**.
2. Go to **Policies** -> **Create policy**.
3. Select the **JSON** editor and paste the following policy (replace `YOUR_S3_BUCKET_NAME` with your actual bucket name):

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "RekognitionLivenessPermissions",
            "Effect": "Allow",
            "Action": [
                "rekognition:CreateFaceLivenessSession",
                "rekognition:GetFaceLivenessSessionResults"
            ],
            "Resource": "*"
        },
        {
            "Sid": "S3AuditBucketPermissions",
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject"
            ],
            "Resource": "arn:aws:s3:::YOUR_S3_BUCKET_NAME/*"
        }
    ]
}
```

4. Click **Next: Tags** -> **Next: Review**.
5. Policy Name: `KolomoniLivenessAccessPolicy`.
6. Click **Create policy**.

### Create an IAM User
1. Go to **Users** -> **Add users**.
2. Username: `kolomoni-liveness-service`.
3. Select **Attach policies directly** and search for `KolomoniLivenessAccessPolicy`.
4. Finish creating the user.
5. Open the created user profile, navigate to the **Security credentials** tab, and click **Create access key**.
6. Select **Application running outside AWS** as the use case.
7. Copy the **Access Key ID** and **Secret Access Key**.

---

## Step 3: Configure the FastAPI Backend
Once you have the credentials, update the `backend/.env` file:

```env
# Change from true to false
MOCK_AWS=false

# Insert credentials
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
AWS_REGION=us-east-1
LIVENESS_BUCKET=kolomoni-liveness-audit
```

Restart the FastAPI backend (e.g. `docker compose up --build`). The backend service will now communicate directly with AWS Rekognition Face Liveness.
