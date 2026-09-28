pipeline {
    agent any

    parameters {
        string(name: 'BRANCH', defaultValue: 'dev', description: 'Git branch to build')
    }

    environment {
        NAMESPACE = 'dev'
        IMAGE_NAME = 'ims-trace-ui'
    }

    stages {
        stage('Checkout SCM') {
            steps {
                git branch: "${params.BRANCH}", credentialsId: 'github-ssh', url: 'git@github.com:arbhutale/ims-ci-logs.git'
            }
        }

        stage('Docker Build & Optimize') {
            steps {
                echo "===> Building Log Viewer & Tracer..."
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
                echo "===> Rolling out to Kubernetes namespace ${NAMESPACE}..."
                sh """
                    kubectl rollout restart deployment/web-log-viewer -n ${NAMESPACE}
                    kubectl rollout status deployment/web-log-viewer -n ${NAMESPACE} --timeout=120s
                """
            }
        }

        stage('Health Check & Smoke Test') {
            steps {
                sh """
                    echo "=== Log Viewer Health Check ==="
                    curl -s -k -o /dev/null -w "Tracer UI HTTP Status: %{http_code}\n" https://logs.smartseth.com/ || true
                    kubectl get pods -n ${NAMESPACE} -l app=web-log-viewer
                """
            }
        }
    }

    post {
        success {
            echo "🎉 CI Logs & Tracer UI Pipeline Completed Successfully!"
        }
        failure {
            echo "❌ CI Logs Pipeline Failed."
        }
    }
}
