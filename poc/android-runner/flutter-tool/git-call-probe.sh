#!/system/bin/sh
echo "FLUTTWARE_GIT_CALL:$*" >&2
case "$*" in
  *"--pretty=format:%ar"*)
    echo "11 days ago"
    ;;
  *"--pretty=format:%H"*)
    echo "058e0af2c2b57e369d905a03ac9748b0ebf543c6"
    ;;
esac
exit 0
