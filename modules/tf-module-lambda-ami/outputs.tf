output "lambda_create_arn" {
  value = "${join(",",aws_lambda_function.create_ami.*.arn)}"
}

output "lambda_delete_arn" {
  value = "${join(",",aws_lambda_function.delete_ami.*.arn)}"
}
