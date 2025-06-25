pipeline {
  agent any

  environment {
    AWS_DEFAULT_REGION = 'us-east-1'
  }

  parameters {
    booleanParam(name: 'DESTROY_BEFORE_APPLY', defaultValue: false, description: 'Destroy resources before creating new ones')
  }

  stages {
    stage('Check VPC Limit and Destroy if Needed') {
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-jenkins-demo']]) {
          script {
            def vpcCount = sh(
              script: 'aws ec2 describe-vpcs --region $AWS_DEFAULT_REGION --query "Vpcs[*].VpcId" --output text | wc -w',
              returnStdout: true
            ).trim().toInteger()

            echo "Current VPC count: ${vpcCount}"

            if (vpcCount >= 5) {
              echo "⚠️ VPC limit reached (${vpcCount}/5). Destroying existing infrastructure..."
              dir('terraform') {
                sh 'terraform destroy -auto-approve'
              }
            } else {
              echo "✅ VPC usage within limit: ${vpcCount}/5"
            }
          }
        }
      }
    }

    stage('Terraform Init') {
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-jenkins-demo']]) {
          dir('terraform') {
            sh 'terraform init'
          }
        }
      }
    }

    stage('Terraform Destroy (If Selected)') {
      when {
        expression { return params.DESTROY_BEFORE_APPLY }
      }
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-jenkins-demo']]) {
          dir('terraform') {
            sh 'terraform destroy -auto-approve'
          }
        }
      }
    }

    stage('Terraform Apply') {
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-jenkins-demo']]) {
          dir('terraform') {
            sh 'terraform apply -auto-approve'
          }
        }
      }
    }

    stage('Generate Ansible Inventory') {
      steps {
        script {
          def bastionIp = sh(script: "terraform -chdir=terraform output -raw bastion_ip", returnStdout: true).trim()
          def mongoIp = sh(script: "terraform -chdir=terraform output -raw mongo_private_ip", returnStdout: true).trim()

          writeFile file: 'ansible/inventory.ini', text: """
[mongo]
mongo1 ansible_host=${mongoIp} ansible_user=ubuntu ansible_ssh_private_key_file=/hom
