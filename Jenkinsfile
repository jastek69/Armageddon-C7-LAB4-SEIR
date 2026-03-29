pipeline {
    agent any
    environment {
        AWS_REGION        = 'us-west-1'
        SONARQUBE_URL     = "https://sonarcloud.io"
        SONAR_SCANNER_HOME = "/opt/sonar-scanner"
        JIRA_SITE         = "https://jastekops.atlassian.net/"
        JIRA_PROJECT      = "SCRUM"
    }

    stages {
        stage('Set AWS Credentials') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
                    sh '''
                      echo "Caller identity:"
                      aws sts get-caller-identity
                    '''
                }
            }
        }

        stage('Checkout Code') {
            steps {
                git branch: 'main', url: 'https://github.com/jastek69/Armageddon-C7-LAB4-SEIR.git'
            }
        }

        stage('Static Code Analysis (SAST)') {
            steps {
                withCredentials([string(credentialsId: 'SONARQUBE_TOKEN', variable: 'SONAR_TOKEN')]) {
                    sh """
                      ${SONAR_SCANNER_HOME}/bin/sonar-scanner \
                        -Dsonar.projectKey=jastekops_pipeline-test-sonarqube \
                        -Dsonar.organization=jastekops \
                        -Dsonar.host.url=${SONARQUBE_URL} \
                        -Dsonar.login=${SONAR_TOKEN}
                    """
                }
            }
        }

        stage('Snyk Security Scan') {
            steps {
                withCredentials([string(credentialsId: 'SNYK_AUTH_TOKEN', variable: 'SNYK_TOKEN')]) {
                    sh """
                      snyk auth ${SNYK_TOKEN}
                      snyk monitor || echo 'No supported files found, monitoring skipped.'
                    """
                }
            }
        }

        stage('Initialize Terraform') {
            steps {
                sh 'terraform init'
            }
        }

        stage('Terraform Deploy') {
            steps {
                withCredentials([
                  [$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds'],
                  file(credentialsId: 'secrets-env', variable: 'SECRETS_FILE')
                ]) {
                  sh """
                    chmod +x terraform_apply.sh
                    source "$SECRETS_FILE"
                    AWS_REGION=${AWS_REGION} \
                    AWS_ACCESS_KEY_ID=\${AWS_ACCESS_KEY_ID} \
                    AWS_SECRET_ACCESS_KEY=\${AWS_SECRET_ACCESS_KEY} \
                    AWS_SESSION_TOKEN=\${AWS_SESSION_TOKEN:-""} \
                    ./terraform_apply.sh
                  """
                }
            }
        }

        stage('Deploy to S3') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
                    sh '''
                        pip3 install --user boto3
                        python3 deploy-to-s3.py --source-dir ./S3-DELIVERABLES --delete
                    '''
                }
            }
        }
    }

    post {
        success { echo 'Terraform deployment completed successfully!' }
        failure { echo 'Terraform deployment failed!' }
    }
}

def createJiraTicket(String issueTitle, String issueDescription) {
    script {
        jiraNewIssue site: "${JIRA_SITE}",
                     projectKey: "${JIRA_PROJECT}",
                     issueType: "Bug",
                     summary: issueTitle,
                     description: issueDescription,
                     priority: "High"
    }
}
