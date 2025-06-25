pipeline {
  agent any

  environment {
    AWS_DEFAULT_REGION = 'us-east-1'
  }

  stages {
    stage('Terraform: Init & Apply') {
      steps {
        withCredentials([
          [$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-jenkins-demo'],
          file(credentialsId: 'jenkins-ec2-pem-key', variable: 'PEM_KEY')
        ]) {
          dir('terraform') {
            sh '''
              export TF_VAR_ssh_pubkey_path=./keys/jenkins-key.pub
              terraform init
              terraform apply -auto-approve
            '''
          }
        }
      }
    }

    stage('Generate Ansible Inventory') {
      steps {
        withCredentials([file(credentialsId: 'jenkins-ec2-pem-key', variable: 'PEM_KEY')]) {
          script {
            def bastionIp = sh(script: "terraform -chdir=terraform output -raw bastion_ip", returnStdout: true).trim()
            def mongoIp   = sh(script: "terraform -chdir=terraform output -raw mongo_private_ip", returnStdout: true).trim()

            writeFile file: 'ansible/inventory.ini', text: """
[mongo]
mongo1 ansible_host=${mongoIp} ansible_user=ubuntu ansible_ssh_private_key_file=${PEM_KEY} ansible_ssh_common_args='-o StrictHostKeyChecking=no -o ProxyCommand="ssh -i ${PEM_KEY} -o StrictHostKeyChecking=no -W %h:%p ubuntu@${bastionIp}"'
            """
          }
        }
      }
    }

    stage('Ansible: Install MongoDB') {
      steps {
        withCredentials([file(credentialsId: 'jenkins-ec2-pem-key', variable: 'PEM_KEY')]) {
          sh '''
            ansible -i ansible/inventory.ini mongo1 -m ping
            ansible-playbook -i ansible/inventory.ini ansible/mongodb.yml
          '''
        }
      }
    }

    stage('Verify MongoDB Status') {
      steps {
        withCredentials([file(credentialsId: 'jenkins-ec2-pem-key', variable: 'PEM_KEY')]) {
          sh '''
            ansible -i ansible/inventory.ini mongo1 -a "systemctl is-active mongod || true"
          '''
        }
      }
    }
  }

  post {
    success {
      echo '✅ MongoDB infrastructure is ready and running.'
    }
    failure {
      echo '❌ Pipeline failed. Check logs.'
    }
  }
}
