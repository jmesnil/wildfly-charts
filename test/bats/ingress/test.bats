setup() {
    load '../../test-common/bats-support/load'
    load '../../test-common/bats-assert/load'
}

setup_file() {
    # Udpate the wildfly chart and its dependencies to be able to use it locally
    pushd ../../charts/wildfly
    helm dep up
    popd

    # Create an application image from the helloworld quickstart and push it 
    # to the Kubernetes image registry at localhost:5001/helloworld
    [ -d target ] || mkdir target
    pushd target
    [ -d quickstart ] || git clone https://github.com/wildfly/quickstart.git
    cd quickstart/helloworld
    mvn -B -Popenshift package wildfly:image
    docker tag helloworld localhost:5001/helloworld
    docker push localhost:5001/helloworld
    popd
    echo "DONE"
}

teardown () {
   helm delete test \
     --wait --timeout=90s
   kubectl delete --ignore-not-found=true secret test-secret-tls
}

@test "Deploy with Ingress" {
    helm install test -f ./ingress/with-ingress.yaml ../../charts/wildfly \
      --wait --timeout=90s
    sleep 2

    run curl -v --no-progress-meter --resolve wildfly.local:80:127.0.0.1 http://wildfly.local/HelloWorld
    assert_output --partial  "200 OK"
    assert_output --partial  "Hello World"
}

@test "Deploy with Ingress with TLS Enabled" {
    pushd target/
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=wildfly.local"
    kubectl create secret tls test-secret-tls --key="tls.key" --cert="tls.crt"
    popd 

    helm install test -f ./ingress/with-tls-ingress.yaml ../../charts/wildfly \
      --wait --timeout=90s
    sleep 5

    # test with HTTPS
    run curl -v -k --no-progress-meter --resolve wildfly.local:443:127.0.0.1 https://wildfly.local/HelloWorld
    assert_output --partial  "*  subject: CN=wildfly.local"
    assert_output --partial  "Hello World"

    # verify that HTTP is redirected to HTTPS
    run curl -v --no-progress-meter --resolve wildfly.local:80:127.0.0.1 http://wildfly.local/HelloWorld
    assert_output --partial "308 Permanent Redirect"

}