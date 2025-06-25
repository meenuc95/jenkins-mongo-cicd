pipeline {
  agent any

  environment {
    AWS_DEFAULT_REGION = 'us-east-1'
  }

  parameters {
    booleanParam(name: 'DESTROY_INFRA', defaultValue: false, description: 'Destroy infrastructure after pipeline ends')
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

            if (vpcCount >= 5) {
              error "⚠️ VPC limit reached ($vpcCount/5). Please destroy existing infra or request a limit increase."
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
      when {
        expression { return !params.DESTROY_INFRA }
      }
      steps {
        script {
          def bastionIp = sh(script: "terraform -chdir=terraform output -raw bastion_ip", returnStdout: true).trim()
          def mongoIp   = sh(script: "terraform -chdir=terraform output -raw mongo_private_ip", returnStdout: true).trim()

          writeFile file: 'ansible/inventory.ini', text: """
[mongo]
mongo1 ansible_host=${mongoIp} ansible_user=ubuntu ansible_ssh_private_key_file=/home/ubuntu/.ssh/ubuntu-slave-jen.pem ansible_ssh_common_args='-o ProxyCommand="ssh -i /home/ubuntu/.ssh/ubuntu-slave-jen.pem -W %h:%p ubuntu@${bastionIp}"'
"""
        }
      }
    }

    stage('Ansible Install MongoDB') {
      when {
        expression { return !params.DESTROY_INFRA }
      }
      steps {
        retry(3) {
          sh '''
            sleep 10
            ansible -i ansible/inventory.ini mongo1 -m ping
            ansible-playbook -i ansible/inventory.ini ansible/mongodb.yml
          '''
        }
      }
    }

    stage('Verify MongoDB') {
      when {
        expression { return !params.DESTROY_INFRA }
      }
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
    always {
      script {
        if (params.DESTROY_INFRA) {
          echo "🔄 DESTROY_INFRA is true. Destroying infrastructure..."
          withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-jenkins-demo']]) {
            dir('terraform') {
              sh 'terraform destroy -auto-approve || echo "⚠️ Terraform destroy failed. Manual cleanup may be needed."'
            }
          }
        }
      }
    }
  }
}
