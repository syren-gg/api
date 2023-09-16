/** @typedef {import("zod")} Zod */

/**
 * AWS Lambda - execution context
 * @typedef {Object} AWSLambdaContext
 *
 * @property {()=>number} getRemainingTimeInMillis
 *    Returns the number of milliseconds left before the execution times out.
 *
 * @property {string} functionName
 *    The name of the Lambda function.
 *
 * @property {string} functionVersion
 *    The version of the function.
 *
 * @property {string} invokedFunctionArn
 *    The ARN that's used to invoke the function.
 *
 * @property {string} memoryLimitInMB
 *    The amount of memory that's allocated for the function.
 */

/**
 * AWS Lambda - API Gateway event
 * @typedef {Object} AWSLambdaAPIGatewayEvent
 *
 * @property {string} path
 *    The request path.
 *
 * @property {("GET"|"POST")} httpMethod
 *    The request HTTP method.
 *
 * @property {Object<string,string>} headers
 *    The request headers.
 *
 * @property {Object<string,string[]>} multiValueHeaders
 *    Multi-value request headers.
 *
 * @property {string} body
 *    The request body.
 */

/**
 * @template T - the RPC event type
 * @callback HandlerCallback
 *
 * @param {T} request
 *    The validated request object.
 *
 * @param {AWSLambdaAPIGatewayEvent} event
 *    The event that triggered the Lambda function.
 *
 * @param {AWSLambdaContext} context
 *    The Lambda execution context.
 */

/**
 * @template T - the RPC event type
 *
 * Creates a Lambda handler function suitable for receiving RPC calls
 * from an API Gateway. The incoming event is validated against a schema and
 * an error is returned to the client if validation fails.
 *
 * @param {Object} options
 * @param {Zod.Schema<T>} options.schema
 *    Them schema to validate the request body against.
 *
 * @param {HandlerCallback<T>} callback
 *    The handler callback.
 */
export function createHandler({ schema }, callback) {
  /**
   * @param {AWSLambdaAPIGatewayEvent} event
   *    The event that triggered the Lambda function.
   *
   * @param {AWSLambdaContext} context
   *    The Lambda execution context.
   */
  return async function (event, context) {
    const body = JSON.parse(event.body);
    const parsed = schema.safeParse(body);

    if (!parsed.success) {
      return {
        statusCode: 400,
        body: JSON.stringify({
          success: false,
          errors: parsed.error.errors.map((error) => ({
            type: "validation",
            path: error.path
              .map((seg) => (typeof seg === "number" ? `[${seg}]` : seg))
              .join("."),
            message: error.message,
          })),
        }),
      };
    }

    return callback(parsed.data, event, context);
  };
}
