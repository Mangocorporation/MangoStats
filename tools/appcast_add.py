"""Adds one release to the Check for Updates feed (site/appcast.xml), newest first.

Usage: appcast_add.py <appcast> <version> <build> '<sign_update output>' <notes.md>
tools/release.sh runs it after notarizing. Adding a version that is already
in the feed replaces it, so a release can be run again.
"""
import re
import sys
from email.utils import formatdate

appcast, version, build, signature, notes_path = sys.argv[1:]
if not re.fullmatch(r'sparkle:edSignature="[A-Za-z0-9+/=]+" length="\d+"', signature.strip()):
    sys.exit(f"unexpected sign_update output: {signature!r}")
notes = open(notes_path, encoding="utf-8").read().strip()
if "]]>" in notes:
    sys.exit("release notes may not contain ]]>")

repo = "https://github.com/Mangocorporation/MangoStats"
item = f"""    <item>
      <title>MangoStats {version}</title>
      <pubDate>{formatdate(usegmt=True)}</pubDate>
      <sparkle:version>{build}</sparkle:version>
      <sparkle:shortVersionString>{version}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>26.0</sparkle:minimumSystemVersion>
      <sparkle:fullReleaseNotesLink>{repo}/releases/tag/v{version}</sparkle:fullReleaseNotesLink>
      <description sparkle:format="markdown"><![CDATA[
{notes}
]]></description>
      <enclosure url="{repo}/releases/download/v{version}/MangoStats-{version}.zip" type="application/octet-stream" {signature.strip()}/>
    </item>
"""

text = open(appcast, encoding="utf-8").read()
# Drop an earlier item for the same version.
text = re.sub(
    r"    <item>\n      <title>MangoStats " + re.escape(version) + r"</title>.*?    </item>\n",
    "", text, flags=re.S)
marker = "    <!-- releases, newest first -->\n"
if marker not in text:
    sys.exit(f"{appcast} lost its marker line: {marker.strip()}")
text = text.replace(marker, marker + item, 1)
open(appcast, "w", encoding="utf-8").write(text)
