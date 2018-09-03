
begin{
    $textPath = "C:\Users\Vitali_Khmialnitski\Documents\learningPS\text.txt"
    $varPath = "C:\Users\Vitali_Khmialnitski\Documents\learningPS\vars.txt"
    $vars = import-csv -Path $varPath
    $text = Get-Content -Path $textPath
    $hash_Vars = [ordered]@{}
}
process{
    foreach($line in $text){
        
    }
    
}
end{

}








