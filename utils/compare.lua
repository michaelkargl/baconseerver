function deepcompare(left,right,ignore_metatables)
    function deepcompare_tables(left, right)
        for key_left, value_left in pairs(left) do
            local value_right = right[key_left];
            
            local value_exists = value_right ~= nil;
            local values_equal = deepcompare(value_left, value_right);
            
            if not value_exists or not values_equal
            then
                print(('%s ~= %s'):format(value_left, value_right))
                return false;
            end
         end
         
         return true;
    end

   local types = {
      left = type(left),
      right = type(right)
   };
   
   if types.left ~= types.right then 
       return false;
   end
   
   -- compare non reference types directly
   if types.left ~= 'table' and types.right ~= 'table' then
       return left == right;
   end

   -- compare tables implementing __eq directly
   local meta_table_left = getmetatable(left);
   if not ignore_metatables and meta_table_left then
       return left == right;
   end

   return deepcompare_tables(left, right) and deepcompare_tables(right, left);
end
	
