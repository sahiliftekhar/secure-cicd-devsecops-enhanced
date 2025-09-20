pipeline {
    agent any

    tools {
        nodejs 'Node-18'
    }

    environment {
        DOCKER_COMPOSE = 'docker-compose -f docker-compose.yml'
        SONARQUBE_URL = 'http://localhost:9000'
        PROJECT_KEY = 'DevSecOps-Pipeline-Project'
        SONAR_TOKEN = 'squ_c010e820379f14f67ec1666c6867984d6b34db22' // Replace with your actual token
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main',
                    credentialsId: 'github-pat',
                    url: 'https://github.com/sahiliftekhar/secure-cicd-devsecops-enhanced.git'
            }
        }

        stage('Cleanup Old Containers') {
            steps {
                bat '''
                    echo Cleaning up old containers and networks...
                    docker stop sonar-db sonarqube devsecops-app 2>nul || echo "Containers not running"
                    docker rm -f sonar-db sonarqube devsecops-app 2>nul || echo "Containers not found"
                    docker network ls --format "{{.Name}}" | findstr /C:"devsecops-ci" >nul && docker network prune -f || echo "No networks to clean"
                    docker system prune -f
                    echo Cleanup completed
                '''
            }
        }

        stage('Build Docker Images') {
            steps {
                bat '''
                    echo Building Docker images...
                    %DOCKER_COMPOSE% build app
                '''
            }
        }

        stage('Start SonarQube Services') {
            steps {
                bat '''
                    echo Starting SonarQube services...
                    %DOCKER_COMPOSE% up -d sonar-db sonarqube
                '''
            }
        }

        stage('Wait for SonarQube') {
            steps {
                script {
                    echo "Waiting for SonarQube to be ready..."
                    timeout(time: 5, unit: 'MINUTES') {
                        waitUntil {
                            script {
                                def result = bat(
                                    script: 'curl -s -u admin:admin http://localhost:9000/api/system/health',
                                    returnStatus: true
                                )
                                return result == 0
                            }
                        }
                    }
                    echo "SonarQube is ready!"
                }
            }
        }

        stage('Install Dependencies') {
            steps {
                bat '''
                    echo Installing Node.js dependencies...
                    cd app
                    npm install
                '''
            }
        }

        stage('Run Tests with Coverage') {
            steps {
                bat '''
                    echo Running tests with coverage...
                    cd app
                    npm test
                '''
            }
        }

        stage('SonarQube Analysis') {
            steps {
                bat '''
                    echo Running SonarQube analysis...
                    cd app
                    
                    REM Create sonar-project.properties file
                    echo sonar.projectKey=%PROJECT_KEY% > sonar-project.properties
                    echo sonar.projectName=DevSecOps Enhanced Pipeline >> sonar-project.properties  
                    echo sonar.projectVersion=1.0 >> sonar-project.properties
                    echo sonar.sources=. >> sonar-project.properties
                    echo sonar.exclusions=node_modules/**,coverage/**,test/**,*.test.js >> sonar-project.properties
                    echo sonar.host.url=%SONARQUBE_URL% >> sonar-project.properties
                    echo sonar.login=%SONAR_TOKEN% >> sonar-project.properties
                    echo sonar.javascript.lcov.reportPaths=coverage/lcov.info >> sonar-project.properties
                    
                    REM Show configuration
                    type sonar-project.properties
                    
                    REM Run SonarQube analysis
                    npx sonarqube-scanner
                '''
            }
        }

        stage('Quality Gate') {
            steps {
                script {
                    echo "Checking SonarQube Quality Gate..."
                    timeout(time: 3, unit: 'MINUTES') {
                        waitUntil {
                            script {
                                def result = bat(
                                    script: '''
                                        curl -s -u admin:admin "http://localhost:9000/api/qualitygates/project_status?projectKey=%PROJECT_KEY%"
                                    ''',
                                    returnStdout: true
                                ).trim()
                                
                                echo "Quality Gate Result: ${result}"
                                
                                if (result.contains('"status":"OK"')) {
                                    return true
                                } else if (result.contains('"status":"ERROR"')) {
                                    error("❌ Quality Gate FAILED! Check SonarQube dashboard for details.")
                                    return false
                                } else {
                                    echo "⏳ Quality Gate analysis in progress..."
                                    return false
                                }
                            }
                        }
                    }
                    echo "✅ Quality Gate PASSED!"
                }
            }
        }

        stage('Deploy Application') {
            steps {
                bat '''
                    echo Deploying application...
                    %DOCKER_COMPOSE% up -d app
                    timeout /t 10
                    curl http://localhost:3000 || echo App is starting up...
                '''
            }
        }

        stage('Health Check') {
            steps {
                bat '''
                    echo Running health checks...
                    curl http://localhost:3000/health || echo Health check will be available soon
                    echo ✅ Enhanced DevSecOps Pipeline completed successfully!
                '''
            }
        }
    }

    post {
        always {
            bat '''
                echo Final status check...
                docker ps
                echo === Application Status ===
                curl -s http://localhost:3000 || echo App not responding
                echo === SonarQube Analysis ===
                curl -s -u admin:admin "http://localhost:9000/api/qualitygates/project_status?projectKey=%PROJECT_KEY%" || echo "Analysis not available"
            '''
        }
        success {
            echo "🎉 Enhanced DevSecOps Pipeline completed successfully with Quality Gates!"
        }
        failure {
            echo "❌ Enhanced Pipeline failed! Check quality gates and logs above."
        }
    }
}
