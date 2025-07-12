sides = {"right", "left", "top", "back" };

index = #(sides) % 2
print(index)

for i,side in pairs(sides) do
   print(side)
end


