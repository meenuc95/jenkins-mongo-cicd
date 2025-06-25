pipeline {
  agent any

  environment {
    AWS_DEFAULT_REGION = 'us-east-1'
  }

  parameters {
    booleanParam(name: 'DESTROY_BEFORE_APPLY', defaultValue: false, description: 'Destroy resources before creating new ones')
  }

  stages {
    stage('Check VPC Limit') {
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-jenkins-demo']]) {
          script {
            def vpcCount = sh(
              script: '''
                echo Checking existing VPC count...
                VPC_COUNT=$(aws ec2 describe-vpcs --region $AWS_DEFAULT_REGION --query "Vpcs[*].VpcId" --output text | wc -w)
                echo "Current VPC count: $VPC_COUNT"
                echo $VPC_COUNT
              ''',
              returnStdout: true
            ).trim().tokenize('\n')[-1].toInteger()

            if (vpcCount >= 5 && !params.DESTROY_BEFORE_APPLY) {
              error "⚠️ VPC limit reached ($vpcCount/5). Either enable DESTROY_BEFORE_APPLY or request a limit increase."
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
          def mongoIp   = sh(script: "terraform -chdir=terraform output -raw mongo_private_ip", returnStdout: true).trim()

          writeFile file: 'ansible/inventory.ini', text: """
[mongo]
mongo1 ansible_host=${mongoIp} ansible_user=ubuntu ansible_ssh_private_key_file=/home/ubuntu/.ssh/jenkins-key ansible_ssh_common_args='-o ProxyCommand="ssh -i /home/ubuntu/.ssh/jenkins-key -W %h:%p ubuntu@${bastionIp}"'
          """
        }
      }
    }

    stage('Ansible Install MongoDB') {
      steps {
        sh '''
          ansible -i ansible/inventory.ini mongo1 -m ping
          ansible-playbook -i ansible/inventory.ini ansible/mongodb.yml
        '''
      }
    }

    stage('Verify MongoDB') {
      steps {
        sh '''
          ansible -i ansible/inventory.ini mongo1 -a "systemctl status mongod || true"
        '''
      }
    }
  }

  post {
    success {
      echo '✅ Jenkins MongoDB Infrastructure pipeline completed.'
    }
    failure {
      echo '❌ Pipeline failed. Check the logs above for details.'
    }
  }
}
