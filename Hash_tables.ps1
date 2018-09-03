$vars = import-csv -Path C:\Users\Vitali_Khmialnitski\Documents\learningPS\vars.txt
$text = Get-Content -Path C:\Users\Vitali_Khmialnitski\Documents\learningPS\text.txt

$hash_Vars = [ordered]@{}

foreach ($item in $vars) {
    $hash_vars.add($item.Variable , $item.Value)
}



