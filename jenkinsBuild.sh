export BUILD_STEPS="${BUILD_STEPS:--FETCH_DOCKER_IMAGES+START_UTILS+CLEAN+BUILD+TEST-SCAN+PACKAGE-EXECUTE_LOCAL+EXECUTE_CONTAINER+INTERGRATION_TEST-UPLOAD}"

do_config() {
	export DEMO_ENV="local"
	export ORG_NAME="damo"
	export APP_NAME="demo"
	export NETWORK_NAME="demo-network"
	export BUILD_VERSION="1.0"
	export DEMO_B_DKR_HOST_PORT="8080"
	export DEMO_B_DKR_CNTR_PORT="8080"
	export SONARQUBE_HOST="localhost"
	export SONARQUBE_USER="admin"
	export SONARQUBE_PASSWORD="admin1"
	export DEMO_TEST_HALT_ON_ERRORS="1"
	export CONTAINER_START_WAIT="10"
	#docker host endpoint
	do_git_info
}
do_git_info() {
	export BUILD_TIME=$(date -u +%Y%m%d%H%M%S)
	export GIT_BRANCH="test git branch"
	#export GIT_BRANCH="${GIT_BRANCH:-$(git rev-parse --abbrev-ref @{u})}";
    #export GIT_BRANCH="${GIT_BRANCH:-$(git show-ref | grep origin | grep $GIT_COMMIT | head -n 1 | cut -f 2 -d ' ')}";
    #export GIT_BRANCH="${GIT_BRANCH:-$(git branch --show-current)}";
	export GIT_COMMIT="test git commit"
	#export GIT_COMMIT="${GIT_COMMIT:-$(git rev-parse HEAD)}"
	export GIT_REPO="test git repo"
	#export GIT_URL="${GIT_URL:-$(git remote get-url origin)}"
    #[[ "$GIT_URL" =~ ^.*github.com/(.*)$ ]] && export GIT_REPO="${BASH_REMATCH[1]/%\.git}"
}
run_clean() {
    echo "--- clean up previous build ---"
	mvn clean
}
run_build() {
    echo "--- build executable jar ---"
	
    echo "mvn validate"
    mvn validate

    echo "mvn compile"
    mvn compile

    echo "mvn -Dmaven.test.skip=true package"
	#tests should be run in a different stage
    mvn -Dmaven.test.skip=true package
}
run_test() {
    echo "--- clean up previous build ---"
	#mvn test -DfailIfNoTests=true 
	mvn test -DfailIfNoTests=false > mvn-verify.log 2>&1 || { errcode=$?; }
	cat mvn-verify.log;
    if [ $errcode -ne 0 ]; then
        echo "--- verify build completed with errors/failures ---"
        exit 1;
    fi
}
run_scan() {
    echo "--- vulnerability scan build ---"
    scan_sonarqube
}
scan_sonarqube() {
    echo "mvn $DEMO_B_MAVEN_LOCAL_REPO sonar:sonar -Dmaven.wagon.http.ssl.insecure=true -Dsonar.host.url=http://${SONARQUBE_HOST}:9000 -Dsonar.login=${SONARQUBE_USER} -Dsonar.password=${SONARQUBE_PASSWORD} -Dsonar.coverage.jacoco.xmlReportPaths=target/site/jacoco/jacoco.xml -Dsonar.dependencyCheck.htmlReportPath=target/dependency-check-report.html"
    mvn $DEMO_B_MAVEN_LOCAL_REPO sonar:sonar \
        -Dmaven.wagon.http.ssl.insecure=true \
        -Dsonar.host.url=http://${SONARQUBE_HOST}:9000 \
		-Dsonar.login=${SONARQUBE_USER} \
		-Dsonar.password=${SONARQUBE_PASSWORD} \
        -Dsonar.coverage.jacoco.xmlReportPaths=target/site/jacoco/jacoco.xml \
        -Dsonar.dependencyCheck.htmlReportPath=target/dependency-check-report.html
	#view report via a web browser, go to http://localhost:9000 login, and then select the project report
}
run_executeLocal() {
    #test url: http://localhost:8080/
	#test url ping: http://localhost:8080/system/healthcheck/ping/
	#test url tdv: http://localhost:8080/system/healthcheck/tdv/
    echo "--- running spring boot as a local server ---"
	
#	echo "--- env outputs ---"
#	echo ${DEMO_ENV}
#	echo ${APP_NAME}
#	echo "--- end env outputs ---"
	
	mvn spring-boot:run
}
run_executeContainer() {
    echo "--- running ${APP_NAME} in a container ---"
	
	
	#remove existing containers and images:
	docker container stop ${APP_NAME}
	docker container rm ${APP_NAME}
	docker image rm ${ORG_NAME}/${APP_NAME}
	
	
	#build the base image
	docker build -t ${ORG_NAME}/${APP_NAME} .
	
	#create the container
	docker container create -p 8080:8080 --name ${APP_NAME} ${ORG_NAME}/${APP_NAME} --network ${NETWORK_NAME}
	#start the container
	docker start ${APP_NAME}

	sleep ${CONTAINER_START_WAIT}
}

run_integration_test() {
    echo "--- test build ---"
    #run automated test suite
	deployment_test
    echo "--- test build completed ---"
}
run_package() {
    echo "-- Running packaging --"
    #rm -rf target/package
    #if [[ -e "${DEMO_CACHE_DIR}/docker" ]]; then cp -r "${DEMO_CACHE_DIR}/docker"/* target; fi
    #cp -r docker/* target
    pushd target > /dev/null

	docker_init
    
    echo
    popd > /dev/null
}

run_upload() {
    echo "-- Upload docker image to Artifactory --"

    pushd target > /dev/null
    artefact_upload
    popd > /dev/null
}

artefact_upload() {
	echo "not implemented yet"
	#todo: add artifactory package upload
}

docker_init() {
	echo "-- Running docker setup --"
	#clear old data
	echo "Docker pruning..."
    #docker container prune -f --filter "until=1h" > /dev/null 2>&1 || { :; } # remove containers stopped over 1h ago
    docker image prune -f > /dev/null 2>&1 || { :; }
    docker volume prune -f > /dev/null 2>&1 || { :; }
    echo "...Docker pruning done"
	
	#create a mesh network for containers to talk to each other over.
    docker_n_exists ${NETWORK_NAME} || {
        echo docker network create ${NETWORK_NAME}
        docker network create ${NETWORK_NAME}
    }   
}
docker_n_exists() {
    docker network inspect ${NETWORK_NAME} > /dev/null 2>&1 || { return $?; }
}

fetch_base_image() {
	echo "-- fetching docker images --"
	#version numbers can be specified, otherwise will fetch latest
	#docker pull eclipse-temurin
	#docker pull postgres
	#docker pull sonarqube
	#docker pull pgadmin4	
}

start_util_containers() {
	if [ $( docker ps -a | grep sonarqube | wc -l ) -gt 0 ]; then
		echo "sonarqube exists already"
	else 
		docker container create -p 9000:9000 --name sonarqube sonarqube:current
	fi
	
	if [ $( docker ps -a | grep pgadmin4 | wc -l ) -gt 0 ]; then
		echo "pgadmin4 exists already"		
	else 	 
		docker run -p 5050:80 \
		--name pgadmin4 \
		-e "PGADMIN_DEFAULT_EMAIL=admin@example.com" \
		-e "PGADMIN_DEFAULT_PASSWORD=admin" \
		-d pgadmin4:current 		
	fi
	
	docker start sonarqube
	docker start pgadmin4
	
	


}

deployment_test() {
    #mkdir -p tmp/demo-test
    pushd tmp/demo-test > /dev/null

    #local dtver=${2}
    #local tst_asset="demo-test-java"
    #echo "--- Test docker $tst_asset $dtver --"

    #fetch_asset3 "${tst_asset}-libs.7z" "IntegrationTests" "${dtver}"
    #if [[ ! -e "lib" ]]; then 7z x -aoa "${tst_asset}-libs.7z"; fi

    #fetch_asset3 "${tst_asset}.7z" "IntegrationTests" "${dtver}"
    #if [[ ! -e "demo-test.jar" ]]; then 7z x -aoa "${tst_asset}.7z"; fi
    #local l_logfile="dtest-java.log"
    

    echo "java -jar demo-test.jar -v"
    java -jar demo-test.jar -v

    if [[ -f "failed" ]]; then
        echo "Tests have completed with failures"
        if [[ "$DEMO_TEST_HALT_ON_ERRORS" == "1" ]]; then exit 1; fi
    fi
    if [[ -f "success" ]]; then
        echo "Tests have completed successfully"
    fi
    popd > /dev/null
}

run() {
	do_config
    if [[ "$1" == "-" ]]; then export BUILD_STEPS="+CLEAN+BUILD+TEST+SCAN+PACKAGE-EXECUTE_LOCAL+EXECUTE_CONTAINER+INTERGRATION_TEST-UPLOAD"; echo "BUILD_STEPS=$BUILD_STEPS"; fi
	if [[ "$BUILD_STEPS" =~ \+FETCH_DOCKER_IMAGES   ]]; then fetch_base_image; fi
	if [[ "$BUILD_STEPS" =~ \+START_UTILS   ]]; then start_util_containers; fi
    if [[ "$BUILD_STEPS" =~ \+CLEAN   ]]; then run_clean; fi
	if [[ "$BUILD_STEPS" =~ \+BUILD   ]]; then run_build; fi
	if [[ "$BUILD_STEPS" =~ \+TEST   ]]; then run_test; fi
	if [[ "$BUILD_STEPS" =~ \+SCAN   ]]; then run_scan; fi
	if [[ "$BUILD_STEPS" =~ \+PACKAGE   ]]; then run_package; fi
	if [[ "$BUILD_STEPS" =~ \+EXECUTE_LOCAL   ]]; then run_executeLocal; fi	
	if [[ "$BUILD_STEPS" =~ \+EXECUTE_CONTAINER   ]]; then run_executeContainer; fi	
	if [[ "$BUILD_STEPS" =~ \+INTERGRATION_TEST   ]]; then run_integration_test; fi
	if [[ "$BUILD_STEPS" =~ \+UPLOAD   ]]; then run_upload; fi
}

run "$1"
