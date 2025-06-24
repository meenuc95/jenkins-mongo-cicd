pipeline {
  agent any

  environment {
    AWS_DEFAULT_REGION = 'us-east-1'
  }

  stages {
    stage('Terraform: Init & Apply') {
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'AWS-Jenkins-Demo']]) {
          dir('terraform') {
            sh '''
              /bin/bash -c "
                export PATH=/opt/homebrew/bin:$PATH
                echo Terraform version:
                terraform init
                terraform apply -auto-approve
              "
            '''
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
mongo1 ansible_host=${mongoIp} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_ed25519 ansible_ssh_common_args='-o ProxyCommand="ssh -i ~/.ssh/id_ed25519 -W %h:%p ubuntu@${bastionIp}"'
          """
        }
      }
    }

    stage('Ansible: Install MongoDB') {
      steps {
        sh '''
          /bin/bash -c "
            export PATH=/opt/homebrew/bin:$PATH
            ansible -i ansible/inventory.ini mongo1 -m ping
            ansible-playbook -i ansible/inventory.ini ansible/mongodb.yml
          "
        '''
      }
    }

    stage('Verify MongoDB Status') {
      steps {
        sh '''
          /bin/bash -c "
            export PATH=/opt/homebrew/bin:$PATH
            ansible -i ansible/inventory.ini mongo1 -a 'systemctl is-active mongod || true'
          "
        '''
      }
    }
  }

  post {
    success {
      echo '✅ MongoDB infra is ready and running.'
    }
    failure {
      echo '❌ Pipeline failed. Check logs.'
    }
  }
}
