with import <nixpkgs> {
  config = {
    android_sdk.accept_license = true;
    allowUnfree = true;
  };
};

let
  buildToolsVersion = "30.0.0";
  
  androidComposition = androidenv.composeAndroidPackages {
    buildToolsVersions = [ buildToolsVersion "29.0.2" ];
    platformVersions = [ "30" ];
    abiVersions = [ "x86" "x86_64"];
  };
in mkShell rec {
  ANDROID_SDK_ROOT = "${androidComposition.androidsdk}/libexec/android-sdk";
  CHROME_EXECUTABLE = "${google-chrome}/bin/google-chrome-stable";
  GRADLE_OPTS = "-Dorg.gradle.project.android.aapt2FromMavenOverride=${ANDROID_SDK_ROOT}/build-tools/${buildToolsVersion}/aapt2";

  buildInputs = [ 
  androidComposition.androidsdk
    jdk
  ];
}
