#!/usr/bin/env bash
set -e

echo "==== INSTALLING BLUEMIX CLI ===="
wget -q -O - https://packages.cloudfoundry.org/debian/cli.cloudfoundry.org.key | sudo apt-key add -
echo "deb https://packages.cloudfoundry.org/debian stable main" | sudo tee /etc/apt/sources.list.d/cloudfoundry-cli.list
# ...then, update your local package index, then finally install the cf CLI
sudo apt-get update
sudo apt-get install cf-cli

echo "============== LOGGING INTO CLOUD FOUNDRY =============="
./bluemix login -a $BLUEMIX_API -s $BLUEMIX_SPACE -o $BLUEMIX_ORGANIZATION -u $BLUEMIX_USER -p $BLUEMIX_PASSWORD

BLUE=$1
GREEN="${BLUE}-B"

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
./cf push $GREEN -f $MANIFEST -b liberty-for-java
# ensure it starts
curl --fail -s -I "https://${GREEN}.${DOMAIN}"

# add the GREEN application to each BLUE route to be load-balanced
# TODO this output parsing seems a bit fragile...find a way to use more structured output
./cf routes | tail -n +4 | grep $BLUE | awk '{print $3" -n "$2}' | xargs -n 3 ./cf map-route $GREEN

# cleanup
# TODO consider 'stop'-ing the BLUE instead of deleting it, so that depedencies are cached for next time
./cf stop $BLUE -f
./cf rename $GREEN $BLUE
./cf delete-route $DOMAIN -n $GREEN -f
finally