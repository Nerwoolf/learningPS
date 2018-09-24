$Errorlog=@()
Try {
get-asdd
} catch {
   $Errorlog+=($_.Exception).Message
}

