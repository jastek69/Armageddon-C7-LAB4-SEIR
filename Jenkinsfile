pipeline {
    agent any
    
    parameters {
        choice(
            name: 'TERRAFORM_ACTION',
            choices: ['apply', 'destroy'],
            description: 'Choose whether to deploy (apply) or destroy infrastructure'
        )
        booleanParam(
            name: 'SKIP_SAST',
            defaultValue: false,
            description: 'Skip Static Code Analysis stage (useful for destroy operations)'
        )
        booleanParam(
            name: 'SKIP_SNYK',
            defaultValue: false,
            description: 'Skip Snyk Security Scan (useful for destroy operations)'
        )
    }
    
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

                stage('IAM Hotfix (Temporary)') {
                        when {
                                expression { params.TERRAFORM_ACTION == 'apply' }
                        }
                        steps {
                                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
                                        sh '''
                                                set -euo pipefail
                                                cat > /tmp/jenkins-missing-perms.json <<'JSON'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "route53:CreateHostedZone",
                "route53:DeleteHostedZone",
                "route53:ListHostedZones",
                "route53:GetHostedZone",
                "route53:ListResourceRecordSets",
                "route53:GetChange",
                "route53:ChangeResourceRecordSets",
                "route53:ListTagsForResource",
                "ec2:AssociateTransitGatewayRouteTable",
                "ec2:DisassociateTransitGatewayRouteTable",
                "ec2:EnableTransitGatewayRouteTablePropagation",
                "ec2:DisableTransitGatewayRouteTablePropagation",
                "ec2:CreateTransitGatewayRoute",
                "ec2:DeleteTransitGatewayRoute"
            ],
            "Resource": "*"
        }
    ]
}
JSON

                                                aws sts get-caller-identity
                                                if ! aws iam put-user-policy \
                                                    --user-name jenkins-programmatic-user \
                                                    --policy-name jenkins-hotfix-tgw-route53 \
                                                    --policy-document file:///tmp/jenkins-missing-perms.json; then
                                                    echo "WARN: IAM hotfix skipped (missing iam:PutUserPolicy)."
                                                    echo "WARN: Ask an admin principal to attach TGW/Route53 permissions to jenkins-programmatic-user."
                                                fi
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
            when {
                expression { params.SKIP_SAST == false }
            }
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
            when {
                expression { params.SKIP_SNYK == false }
            }
            steps {
                withCredentials([string(credentialsId: 'SNYK_AUTH_TOKEN', variable: 'SNYK_TOKEN')]) {
                    sh """
                      snyk auth ${SNYK_TOKEN}
                      snyk monitor || echo 'No supported files found, monitoring skipped.'
                    """
                }
            }
        }

        stage('Scaffolding Validation') {
            steps {
                sh '''
                    set -euo pipefail
                    test -f terraform_startup.sh
                    test -f terraform_apply.sh
                    test -d Tokyo
                    test -d global
                    test -d newyork_gcp
                    test -d saopaulo
                '''
            }
        }

        stage('Terraform Deploy') {
            steps {
                withCredentials([
                                                                        [$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds'],
                  file(credentialsId: 'secrets-env', variable: 'SECRETS_FILE'),
                  file(credentialsId: 'gcp-credentials-json', variable: 'GCP_CREDS'),
                  file(credentialsId: 'gcp-nihonmachi-cert', variable: 'GCP_CERT'),
                  file(credentialsId: 'gcp-nihonmachi-key', variable: 'GCP_KEY')
                ]) {
                  script {
                    if (params.TERRAFORM_ACTION == 'destroy') {
                      echo "=== DESTROYING INFRASTRUCTURE ==="
                                            sh '''
                                                set -euo pipefail
                        chmod +x terraform_destroy.sh
                        source "$SECRETS_FILE"
                        
                        # Set up GCP credential paths
                        export GOOGLE_APPLICATION_CREDENTIALS="$GCP_CREDS"
                        export TF_VAR_gcp_credentials="$GCP_CREDS"
                        
                        # Create symlinks for certificates
                        mkdir -p newyork_gcp/certs
                        ln -sf "$GCP_CERT" newyork_gcp/certs/nihonmachi-ilb.crt || cp "$GCP_CERT" newyork_gcp/certs/nihonmachi-ilb.crt
                        ln -sf "$GCP_KEY" newyork_gcp/certs/nihonmachi-ilb.key || cp "$GCP_KEY" newyork_gcp/certs/nihonmachi-ilb.key
                        
                        AWS_REGION=${AWS_REGION} \
                        AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
                        AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
                        ./terraform_destroy.sh
                                            '''
                    } else {
                                            echo "=== DEPLOYING INFRASTRUCTURE (STAGED SCAFFOLD) ==="
                                            sh '''
                                                set -euo pipefail
                                                chmod +x terraform_startup.sh
                        source "$SECRETS_FILE"
                        
                        # Set up GCP credential paths
                        export GOOGLE_APPLICATION_CREDENTIALS="$GCP_CREDS"
                        export TF_VAR_gcp_credentials="$GCP_CREDS"
                        
                        # Create symlinks for certificates
                        mkdir -p newyork_gcp/certs
                        ln -sf "$GCP_CERT" newyork_gcp/certs/nihonmachi-ilb.crt || cp "$GCP_CERT" newyork_gcp/certs/nihonmachi-ilb.crt
                        ln -sf "$GCP_KEY" newyork_gcp/certs/nihonmachi-ilb.key || cp "$GCP_KEY" newyork_gcp/certs/nihonmachi-ilb.key
                        
                        AWS_REGION=${AWS_REGION} \
                        AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
                        AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
                                                ./terraform_startup.sh
                                            '''
                    }
                  }
                }
            }
        }

        stage('Deploy to S3') {
            when {
                expression { params.TERRAFORM_ACTION == 'apply' }
            }
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
                    sh '''
                        pip3 install --user boto3
                        python3 deploy-to-s3.py --source-dir ./S3-DELIVERABLES --delete
                    '''
                }
            }
        }
    }

    post {
        success { 
            script {
                if (params.TERRAFORM_ACTION == 'destroy') {
                    echo 'Infrastructure destruction completed successfully!'
                } else {
                    echo 'Terraform deployment completed successfully!'
                }
            }
        }
        failure { 
            script {
                if (params.TERRAFORM_ACTION == 'destroy') {
                    echo 'Infrastructure destruction failed!'
                } else {
                    echo 'Terraform deployment failed!'
                }
            }
        }
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
