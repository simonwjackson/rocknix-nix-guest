# Initial AYN Odin 2 Portal profile.
#
# Odin 2 Portal is an SM8550-family target, so start from the shared SM8550
# defaults and keep the per-device override surface explicit. Replace these
# inherited values with measured Odin 2 Portal display/input/audio/performance
# data as hardware evidence comes in.
{ ... }:

{
  rocknix.sm8550.deviceId = "odin2portal";
}
