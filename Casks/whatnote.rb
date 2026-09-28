cask "whatnote" do
  version "1.2.2"
  sha256 "6bb9413d2ced967de2b3bc9fcf8ad8f6e210011837d9e37708a5cbb94e0db659"

  url "https://github.com/yx1100/Deskbit/releases/download/v#{version}/Whatnote-v#{version}-macOS-arm64.zip"
  name "Whatnote"
  name "随便记"
  desc "Native desktop sticky notes with spatial organization"
  homepage "https://github.com/yx1100/Deskbit"

  depends_on arch: :arm64
  depends_on macos: :big_sur

  app "Whatnote.app"
end
