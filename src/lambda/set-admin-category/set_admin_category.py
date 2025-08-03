def lambda_handler(event, context):
    user_attrs = event["request"]["userAttributes"]

    if user_attrs.get('custom:role') == 'admin':
        event["response"]["autoConfirmUser"] = True
        event["response"]["autoVerifyEmail"] = True
        event["request"]["userAttributes"]["custom:category"] = "Network"

    return event
