{ lib, ... }:
{
  # PipeWire is the only sound server (section 8.2).
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true; # 32-bit games / Steam runtime
    pulse.enable = true; # PulseAudio clients (browsers, Steam)
    wireplumber.enable = true;
    jack.enable = lib.mkDefault false;
  };
}
