pipeline {
  agent any

  environment {
    AWS_DEFAULT_REGION = 'us-east-1'
  }

  parameters {
    booleanParam(name: 'DESTROY_BEFORE_APPLY', defaultValue: false, description: 'Destroy resources before creating new ones')
  }

  stages {
    stage('Pre-check: AWS Key Pair') {
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-jenkins-demo']]) {
          sh '''
            if ! aws ec2 describe-key-pairs --key-names jenkins-key --region $AWS_DEFAULT_REGION > /dev/null 2>&1; then
              echo "Importing Jenkins keypair..."
              aws ec2 import-key-pair \
                --key-name jenkins-key \
                --public-key-material fileb:///home/ubuntu/jenkins-key.pub \
                --region $AWS_DEFAULT_REGION
            else
              echo "Keypair 'jenkins-key' already exists. Skipping import."
            fi
          '''
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
mongo1 ansible_host=${mongoIp} ansible_user=ubuntu ansible_ssh_private_key_file=/home/ubuntu/jenkins-key ansible_ssh_common_args='-o ProxyCommand="ssh -i /home/ubuntu/jenkins-key -W %h:%p ubuntu@${bastionIp}"'
          """
        }
      }
    }

    stage('Ansible: Install MongoDB') {
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
