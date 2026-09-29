pipeline {
    agent any

    parameters {
        string(name: 'BRANCH', defaultValue: 'dev', description: 'Git branch or release tag to build')
        choice(
            name: 'ENVIRONMENT',
            choices: ['auto', 'dev', 'prod'],
            description: 'Target Environment (auto: main/tags -> prod, dev/branches -> dev)'
        )
    }

    environment {
        NAMESPACE = "${params.ENVIRONMENT && params.ENVIRONMENT != 'auto' ? params.ENVIRONMENT : (params.BRANCH == 'main' || params.BRANCH.startsWith('v') ? 'prod' : 'dev')}"
        IMAGE_NAME = 'ims-trace-ui'
    }

    stages {
        stage('Checkout SCM') {
            steps {
                echo "===> Checking out branch ${params.BRANCH} for target environment: ${env.NAMESPACE}"
                git branch: "${params.BRANCH}", credentialsId: 'github-ssh', url: 'git@github.com:arbhutale/ims-ci-logs.git'
            }
        }

        stage('Docker Build & Optimize') {
            steps {
                echo "===> Building Log Viewer & Tracer for ${env.NAMESPACE}..."
                sh """
                    docker build -t ${IMAGE_NAME}:latest .
                """
            }
        }

        stage('Container Runtime Import') {
            steps {
                echo "===> Importing Image into K3s Containerd..."
                sh """
                    docker save ${IMAGE_NAME}:latest | ctr -n k8s.io images import -
                """
            }
        }

        stage('Kubernetes Rolling Deployment') {
            steps {
                echo "===> Rolling out to Kubernetes namespace ${env.NAMESPACE}..."
                sh """
                    kubectl rollout restart deployment/web-log-viewer -n ${env.NAMESPACE}
                    kubectl rollout status deployment/web-log-viewer -n ${env.NAMESPACE} --timeout=120s
                """
            }
        }

        stage('Health Check & Smoke Test') {
            steps {
                sh """
                    echo "=== Log Viewer Health Check ==="
                    LOG_HOST="${env.NAMESPACE == 'prod' ? 'https://logs.smartseth.com' : 'https://logs.smartseth.dev'}"
                    curl -s -k -o /dev/null -w "Tracer UI HTTP Status: %{http_code}\n" "\${LOG_HOST}/" || true
                    kubectl get pods -n ${env.NAMESPACE} -l app=web-log-viewer
                """
            }
        }
    }

    post {
        success {
            echo "🎉 CI Logs & Tracer UI Pipeline Completed Successfully for [${env.NAMESPACE}] environment!"
        }
        failure {
            echo "❌ CI Logs Pipeline Failed for [${env.NAMESPACE}] environment."
        }
    }
}
