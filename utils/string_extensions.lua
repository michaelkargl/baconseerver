
function string.startsWith(source, startsWith)
   local beginning = string.sub(source, 1, string.len(startsWith))
   return beginning == startsWith
end

function string.trimStart(source, trim)
   if(not string.startsWith(source, trim)) then
      return source
   end
   
   return string.sub(source, string.len(trim) + 1)
end
