resource "aws_codedeploy_deployment_group" "group" {

  app_name               = aws_codedeploy_app.app.name
  deployment_group_name  = "bluegreen-group"
  service_role_arn       = aws_iam_role.codedeploy_role.arn
  deployment_config_name = "CodeDeployDefault.OneAtATime"

  autoscaling_groups = [
    aws_autoscaling_group.blue_asg.name
  ]

  deployment_style {
    deployment_type   = "BLUE_GREEN"
    deployment_option = "WITH_TRAFFIC_CONTROL"
  }

  blue_green_deployment_config {

    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }

    green_fleet_provisioning_option {
      action = "COPY_AUTO_SCALING_GROUP"
    }

    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }
  }

  load_balancer_info {

    target_group_info {
      name = aws_lb_target_group.blue.name
    }

    target_group_info {
      name = aws_lb_target_group.green.name
    }
  }

  auto_rollback_configuration {
    enabled = true
    events  = [
      "DEPLOYMENT_FAILURE",
      "DEPLOYMENT_STOP_ON_ALARM",
      "DEPLOYMENT_STOP_ON_REQUEST"
    ]
  }

  depends_on = [
    aws_lb_listener.http,
    aws_lb_target_group.blue,
    aws_lb_target_group.green
  ]
}
