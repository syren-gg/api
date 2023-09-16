import { z } from "zod";
import { createHandler } from "@syren-gg/lambda-rpc";
import { SNSClient, PublishCommand } from "@aws-sdk/client-sns";

const client = new SNSClient({});

export const handler = createHandler({
  schema: z.object({
    email: z.string().email(),
  })
}, async (request) => {
  const { email } = request;

  const command = new PublishCommand({
    TopicArn: process.env.MARKETING_EVENTS_TOPIC_ARN,
    Subject: "gg.syren.marketing.MailingListSubscribed-v1/json",
    Message: JSON.stringify({
      email,
    })
  })

  await client.send(command);

  return {
    statusCode: 202,
    body: JSON.stringify({ success: true }),
  }
})
