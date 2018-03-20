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

MANIFEST="manifest.yml"
# get route, app name (BLUE), and domain
ROUTE=`cat $MANIFEST | grep route: | awk '{print $3}'`

BLUE=`echo $ROUTE | sed -e 's,\..*,,'`
echo "App name is $BLUE"

GREEN="${BLUE}-B"
TEMP="${BLUE}-old"

DOMAIN=`echo $ROUTE | sed -e "s,$BLUE\.,,"`

# finally ()
# {
#     # we don't want to keep the sensitive information around
#     rm $MANIFEST
# }

# create the GREEN application
./cf push $GREEN -p ./target/openliberty.war -b liberty-for-java

# ensure it starts
echo "Checking status of new instance https://${GREEN}.${DOMAIN}..."
curl --fail -s -I "https://${GREEN}.${DOMAIN}" --connect-timeout 120 --max-time 180

# add the GREEN application to each BLUE route to be load-balanced
# TODO this output parsing seems a bit fragile...find a way to use more structured output
echo "Rerouting main site to new deployment..."
./cf routes | tail -n +4 | grep $BLUE | awk '{print $3" -n "$2}' | xargs -n 3 ./cf map-route $GREEN

# cleanup
# TODO consider 'stop'-ing the BLUE instead of deleting it, so that depedencies are cached for next time
echo "Cleaning up after blue-green deployment..."
./cf stop $BLUE
./cf delete-route $DOMAIN -n $GREEN -f
./cf rename $BLUE $TEMP
./cf rename $GREEN $BLUE
./cf rename $TEMP $GREEN
# finally