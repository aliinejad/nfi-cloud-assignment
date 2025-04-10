variable "overnight_notification_emails" {
  description = "List of email addresses for overnight notification subscriptions"
  type        = list(string)
  default     = ["user1@example.com", "user2@example.com"]
}