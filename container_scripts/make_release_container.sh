#!/bin/bash
WORK="/opt/work"


source /tmp/.venv/bin/activate

cd $WORK

version=0.1.$(date -u +%Y%m%d%H%M)
sed -i "s/\"version\": \"[^\"]*\"/\"version\": \"$version\"/" app/redhat_insights/app.manifest
sed -i "s/version = .*/version = $version/" app/redhat_insights/default/app.conf

slim validate app/redhat_insights
slim package app/redhat_insights

# GIT_REV=`git rev-parse --short HEAD`
branch_name=$(cat .git/HEAD | cut -d' ' -f2-)
GIT_REV=`cut -c 1-7 .git/$branch_name`

mv "redhat_insights-${version}.tar.gz" "redhat_insights-${version}-${GIT_REV}.tar.gz"

/opt/splunk/bin/splunk install app "./redhat_insights-${version}-${GIT_REV}.tar.gz"
