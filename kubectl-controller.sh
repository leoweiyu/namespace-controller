whitelist=("default" "kube-system")

namespace_label_whitelist=("control-plane" "container-team")
array_namespace_label_whitelist=namespace_label_whitelist[@]

subResources_tiers=("quota-default" "quota-big" "quota-small")
array_subResources_tiers=subResources_tiers[@]

array_contains () {
    local array="$1[@]"
    local seeking=$2
    local in=1
    for element in "${!array}"; do
        if [[ $element == "$seeking" ]]; then
            in=0
            break
        fi
    done
    return $in
}

createSubResources() {
  echo "Creating subresources"
  echo "tier is $1"
  #kubectl apply -f /tmp/$1 -n $2
  echo "Created subresources"
}

updateSubResources() {
  echo "Updating subresources"
  echo "tier is $1"
  #kubectl apply -f /tmp/$1 -n $2
  echo "Updated subresources"
}

deleteSubResources() {
  echo "Deleting subresources"
  #kubectl delete quota --all -n $1
  echo "Deleted subresources"
  
}

checkDiff() {
  kubectl diff -f /tmp/$1 -n $2 1>/dev/null 2>&1
  x=$?
  #echo "Checking quota $1"
  if test $x = 0
  then
    echo "no"
  else
    echo "yes"
  fi
}


kubectl get ns -w --output-watch-events -o json|jq -c --unbuffered 'del(.object.metadata.annotations)'|while read GAGA
do
  echo "########################"
  date
  E_type=`echo $GAGA|jq '.type'|tr -d '"'`
  echo "event type is $E_type"
  Namespace=`echo $GAGA|jq '.object.metadata.name'|tr -d '"'`
  echo "namespace name is $Namespace"
  Labels=`echo $GAGA|jq -c '.object.metadata.labels'`
  echo "labels defined are $Labels"

  in_whitelist=`array_contains whitelist $Namespace && echo yes || echo no`
  if [[ $in_whitelist == "yes" ]]
  then
    echo "namespace $Namespace found in namespace white list, nothing to do."
    continue
  fi

  ignoreme=`echo $Labels|jq 'has("namespace-default-configurator-ignore")'`
  if [[ $ignoreme == "true" ]]
  then
    echo "namespace label 'namespace-default-configurator-ignore' found in namespace $Namespace, nothing to do."
    continue
  fi

  ignoreme_because_whitelist_label="false"
  my_whitelist_label=""
  for whitelist_label in "${!array_namespace_label_whitelist}"
  do
    #echo "whitelist_label is $whitelist_label"
    R_whitelist_label='"'$whitelist_label'"'
    ignoreme_because_whitelist_label=`echo $Labels|jq "has($R_whitelist_label)"`
    if [[ $ignoreme_because_whitelist_label == "true" ]]
    then
      my_whitelist_label=$whitelist_label
      break
    fi
  done

  if [[ $ignoreme_because_whitelist_label == "true" ]]      
  then
    echo "whitelist label $my_whitelist_label found in namespace $Namespace, nothing to do"
    continue
  fi


  if [[ $E_type == "ADDED" ]]
  then
    echo "ADDED situation"
    tier_label="quota-default"
    for tier in "${!array_subResources_tiers}"
    do
      R_tier='"'$tier'"'
      tier_label_found=`echo $Labels|jq "has($R_tier)"`
      if [[ $tier_label_found == "true" ]]
      then
        tier_label=$tier
        break
      fi
    done
    my_diff=`checkDiff $tier_label $Namespace`
    if [[ $my_diff == "yes" ]]
    then 
      echo "Diff found, create sub resources"
      createSubResources $tier_label $Namespace
    else
      echo "Nothing changed, contiue"
      continue
    fi
  elif [[ $E_type == "MODIFIED" ]]
  then
    echo "MODIFIED situation"
    tier_label=""
    for tier in "${!array_subResources_tiers}"
    do
      R_tier='"'$tier'"'
      tier_label_found=`echo $Labels|jq "has($R_tier)"`
      if [[ $tier_label_found == "true" ]]
      then
        tier_label=$tier
        break
      fi
    done
    if [[ $tier_label == "" ]]
    then
      deleteSubResources $Namespace
    else
      updateSubResources $tier_label $Namespace
    fi
      
    
  else
    echo "type is $E_type"
    echo "DO Nothing"
  fi

done
