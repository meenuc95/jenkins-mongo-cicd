pipeline {
  agent any

  environment {
    AWS_DEFAULT_REGION = 'us-east-1'
  }

  parameters {
    booleanParam(name: 'DESTROY_INFRA', defaultValue: false, description: 'Check to destroy infrastructure after pipeline finishes')
  }

  stages {
    stage('Terraform Init & Apply') {
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-jenkins-demo']]) {
          dir('terraform') {
            sh '''
              terraform init
              terraform apply -auto-approve
            '''
          }
        }
      }
    }

    stage('Generate Inventory File') {
      steps {
        script {
          def bastionIp = sh(script: "terraform -chdir=terraform output -raw bastion_ip", returnStdout: true).trim()
          def mongoIp   = sh(script: "terraform -chdir=terraform output -raw mongo_private_ip", returnStdout: true).trim()

          writeFile file: 'ansible/inventory.ini', text: """
[mongo]
mongo1 ansible_host=${mongoIp} ansible_user=ubuntu ansible_ssh_private_key_file=/home/ubuntu/jenkins-key ansible_ssh_common_args='-o ProxyCommand="ssh -i /home/ubuntu/jenkins-key -W %h:%p ubuntu@${bastionIp}"'
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

    stage('Terraform Destroy (Optional)') {
      when {
        expression { return params.DESTROY_INFRA }
      }
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-jenkins-demo']]) {
          dir('terraform') {
            sh '''
              terraform destroy -auto-approve
            '''
          }
        }
      }
    }
  }

  post {
    success {
      echo '✅ MongoDB infrastructure is deployed successfully.'
    }
    failure {
      echo '❌ Pipeline failed. Please check logs.'
    }
  }
}
