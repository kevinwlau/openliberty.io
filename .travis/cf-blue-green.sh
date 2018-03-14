#!/usr/bin/env bash
set -e

echo "============== INSTALLING CLOUD FOUNDRY CLI CLIENT =============="
# https://github.com/cloudfoundry/cli/releases
wget --max-redirect=1 --output-document=cf_cli_6.35.0.tgz "https://cli.run.pivotal.io/stable?release=linux64-binary&version=6.35.0&source=github-rel"
gunzip cf_cli_6.35.0.tgz
tar -xvf cf_cli_6.35.0.tar

echo "============== LOGGING INTO CLOUD FOUNDRY =============="
echo `pwd`
./cf login -a=$BLUEMIX_API -s=$BLUEMIX_SPACE -o=$BLUEMIX_ORGANIZATION -u=$BLUEMIX_USER -p=$BLUEMIX_PASSWORD

BLUE=$1
GREEN="${BLUE}-B"
TEMP="${BLUE}-old"

finally ()
{
    # we don't want to keep the sensitive information around
    rm $MANIFEST
}

# pull the up-to-date manifest from the BLUE (existing) application
MANIFEST=$(mktemp -t "${BLUE}_manifest.XXXXXXXXXX")
./cf create-app-manifest $BLUE -p $MANIFEST

# grab domain from BLUE MANIFEST
DOMAIN=$(cat $MANIFEST | grep domain: | awk '{print $2}')}

# create the GREEN application
./cf push $GREEN -p ./target/openliberty.war -f $MANIFEST -b liberty-for-java

# ensure it starts
# echo "Checking status of new instance..."
# curl --fail -s -I "https://${GREEN}.${DOMAIN}"

# add the GREEN application to each BLUE route to be load-balanced
# TODO this output parsing seems a bit fragile...find a way to use more structured output
# echo "Rerouting main site..."
# ./cf routes | tail -n +4 | grep $BLUE | awk '{print $3" -n "$2}' | xargs -n 3 ./cf map-route $GREEN

# cleanup
# TODO consider 'stop'-ing the BLUE instead of deleting it, so that depedencies are cached for next time
echo "Cleaning up after blue-green deployment..."
./cf stop $BLUE
./cf rename $BLUE $TEMP
./cf rename $GREEN $BLUE
./cf delete $TEMP -f
finally