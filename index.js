import { S3Client, GetObjectCommand } from '@aws-sdk/client-s3';
import { SESClient, SendRawEmailCommand } from '@aws-sdk/client-ses';

const s3Client = new S3Client({});
const sesClient = new SESClient({});

export const handler = async (event) => {
  console.log('Received SES event:', JSON.stringify(event, null, 2));

  const forwardToEmail = process.env.FORWARD_TO_EMAIL;
  const s3Bucket = process.env.S3_BUCKET;
  const s3Prefix = process.env.S3_PREFIX || '';

  if (!forwardToEmail) {
    throw new Error('FORWARD_TO_EMAIL environment variable is not set');
  }

  if (!s3Bucket) {
    throw new Error('S3_BUCKET environment variable is not set');
  }

  const results = [];

  // Process each SES record
  for (const record of event.Records) {
    try {
      if (record.eventSource !== 'aws:ses') {
        console.log('Skipping non-SES record');
        continue;
      }

      const sesMessage = record.ses;
      const messageId = sesMessage.mail.messageId;

      console.log(`Processing message ${messageId}`);

      // Construct S3 object key from message ID
      // SES stores emails using the message ID as the key
      const objectKey = s3Prefix + messageId;

      console.log(`Fetching email from S3: ${s3Bucket}/${objectKey}`);

      let emailContent;
      try {
        const getObjectCommand = new GetObjectCommand({
          Bucket: s3Bucket,
          Key: objectKey,
        });

        const s3Response = await s3Client.send(getObjectCommand);
        emailContent = await streamToString(s3Response.Body);
      } catch (s3Error) {
        console.error(`Failed to fetch email from S3: ${s3Bucket}/${objectKey}`, s3Error);
        throw new Error(`S3 fetch failed: ${s3Error.message}`);
      }

      // Check for forwarding loop - if this email was already forwarded by us, skip it
      if (emailContent.includes('X-Forwarded-By: SES-Email-Forwarder')) {
        console.log(`Skipping message ${messageId} - already forwarded (loop prevention)`);
        results.push({ messageId, status: 'skipped', reason: 'loop-prevention' });
        continue;
      }

      // Parse the original email headers
      const originalFrom = sesMessage.mail.commonHeaders.from?.[0] || 'unknown';
      const originalTo = sesMessage.mail.commonHeaders.to || [];
      const originalSubject = sesMessage.mail.commonHeaders.subject || '(No Subject)';

      console.log(`Original from: ${originalFrom}`);
      console.log(`Original to: ${originalTo.join(', ')}`);
      console.log(`Original subject: ${originalSubject}`);

      // Modify the email to add forwarding information
      let forwardedEmail;
      try {
        forwardedEmail = modifyEmail(emailContent, {
          originalFrom,
          originalTo,
          forwardToEmail,
        });
      } catch (modifyError) {
        console.error(`Failed to modify email ${messageId}:`, modifyError);
        throw new Error(`Email modification failed: ${modifyError.message}`);
      }

      // Send the forwarded email
      try {
        const sendRawEmailCommand = new SendRawEmailCommand({
          RawMessage: {
            Data: Buffer.from(forwardedEmail),
          },
        });

        await sesClient.send(sendRawEmailCommand);
        console.log(`Successfully forwarded message ${messageId} to ${forwardToEmail}`);
        results.push({ messageId, status: 'success' });
      } catch (sesError) {
        console.error(`Failed to send email ${messageId}:`, sesError);
        throw new Error(`SES send failed: ${sesError.message}`);
      }
    } catch (recordError) {
      console.error(`Error processing record:`, recordError);
      results.push({
        messageId: record.ses?.mail?.messageId || 'unknown',
        status: 'error',
        error: recordError.message,
      });
      // Continue processing other records instead of failing completely
    }
  }

  const successCount = results.filter(r => r.status === 'success').length;
  const errorCount = results.filter(r => r.status === 'error').length;
  const skippedCount = results.filter(r => r.status === 'skipped').length;

  console.log(`Processing complete: ${successCount} success, ${errorCount} errors, ${skippedCount} skipped`);

  return {
    statusCode: errorCount > 0 ? 207 : 200, // 207 Multi-Status if some failed
    body: JSON.stringify({
      message: 'Email processing complete',
      results,
      summary: { successCount, errorCount, skippedCount },
    }),
  }
};

/**
 * Convert a readable stream to a string
 */
async function streamToString(stream) {
  const chunks = [];
  for await (const chunk of stream) {
    chunks.push(chunk);
  }
  return Buffer.concat(chunks).toString('utf-8');
}

/**
 * Modify the email to add forwarding information and change recipient
 */
function modifyEmail(emailContent, { originalFrom, originalTo, forwardToEmail }) {
  // Split headers and body
  const emailParts = emailContent.split('\r\n\r\n');
  const headers = emailParts[0];
  const body = emailParts.slice(1).join('\r\n\r\n');

  // Parse headers
  const headerLines = headers.split('\r\n');
  const modifiedHeaders = [];
  let replyToHeaderFound = false;

  for (const line of headerLines) {
    // Skip Return-Path, Sender, Reply-To, and To headers - we'll add our own
    if (line.match(/^Return-Path:/i)) {
      continue;
    }
    if (line.match(/^Sender:/i)) {
      continue;
    }
    if (line.match(/^Reply-To:/i)) {
      replyToHeaderFound = true;
      continue;
    }
    if (line.match(/^To:/i)) {
      continue;
    }
    if (line.match(/^From:/i)) {
      modifiedHeaders.push(line);
      continue;
    }

    // Keep all other headers
    modifiedHeaders.push(line);
  }

  // Add forwarding headers
  if (!replyToHeaderFound) {
    modifiedHeaders.push(`Reply-To: ${originalFrom}`);
  }

  // Add original recipient information in X-headers
  modifiedHeaders.push(`X-Original-To: ${originalTo.join(', ')}`);
  modifiedHeaders.push(`X-Forwarded-By: SES-Email-Forwarder`);

  // Set the new recipient
  modifiedHeaders.push(`To: ${forwardToEmail}`);

  // Reconstruct the email
  const modifiedEmail = modifiedHeaders.join('\r\n') + '\r\n\r\n' + body;

  return modifiedEmail;
}
