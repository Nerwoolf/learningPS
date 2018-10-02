$site = "https://dodopizza.by/minsk"
$request = Invoke-WebRequest -Uri $site
$request | gm