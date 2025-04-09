import boto3
import datetime
import os
from botocore.exceptions import ClientError

def get_cost_report(ce_client, start_date: str, end_date: str) -> dict:
    return ce_client.get_cost_and_usage(
        TimePeriod={'Start': start_date, 'End': end_date},
        Granularity='DAILY',
        Metrics=['UnblendedCost'],
        GroupBy=[
            {"Type": "DIMENSION", "Key": "SERVICE"},
            {"Type": "DIMENSION", "Key": "USAGE_TYPE"}
        ]
    )

def format_daily_report(results: list) -> str:
    report_lines = []
    for day in results:
        date_str = day['TimePeriod']['Start']
        report_lines.append(f"Date: {date_str}")
        groups = day.get("Groups", [])
        calculated_total = 0.0
        if groups:
            for group in groups:
                group_label = ", ".join(group.get("Keys", []))
                amount_str = group.get("Metrics", {}).get("UnblendedCost", {}).get("Amount", "0")
                try:
                    amount = float(amount_str)
                except ValueError:
                    amount = 0.0
                calculated_total += amount
                report_lines.append(f"  {group_label}: ${amount:.2f}")
        else:
            report_lines.append("  No group breakdown available.")
        total_str = day.get("Total", {}).get("UnblendedCost", {}).get("Amount", "0")
        try:
            api_total = float(total_str)
        except ValueError:
            api_total = 0.0
        report_lines.append(f"API Total: ${api_total:.2f}")
        report_lines.append(f"Calculated Total: ${calculated_total:.2f}")
        report_lines.append("")
    return "\n".join(report_lines)

def publish_report(sns_client, topic_arn: str, subject: str, message: str) -> dict:
    return sns_client.publish(
        TopicArn=topic_arn,
        Subject=subject,
        Message=message
    )

def lambda_handler(event, context):
    sns_topic_arn = os.environ.get('SNS_TOPIC_ARN')
    if not sns_topic_arn:
        raise Exception("SNS_TOPIC_ARN not set in environment variables")
    ce_client = boto3.client('ce')
    sns_client = boto3.client('sns')
    today = datetime.date.today()
    start_date = (today - datetime.timedelta(days=2)).isoformat()
    end_date = today.isoformat()
    try:
        cost_response = get_cost_report(ce_client, start_date, end_date)
    except ce_client.exceptions.DataUnavailableException as e:
        error_message = f"Cost data unavailable for period {start_date} to {end_date}: {e}"
        print(error_message)
        return {"status": "Data unavailable", "message": error_message}
    except ClientError as ce_error:
        print(f"ClientError: {ce_error}")
        return {"status": "Error", "message": str(ce_error)}
    report = format_daily_report(cost_response.get("ResultsByTime", []))
    publish_response = publish_report(sns_client, sns_topic_arn, "EC2 Termination Billing Detailed Report", report)
    return {"status": "Report sent", "sns_response": publish_response, "report": report}
