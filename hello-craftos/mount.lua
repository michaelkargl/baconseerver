-- Mounting can be done in various ways
--   From the shell (mount/unmount)
--   From Lua (mounter.*)
--   From the command line (craftos startup params)
--   https://www.craftos-pc.cc/docs/mounter
--
-- This file demonstrates the lua way for easier automation later on

local_source_path='/media/veracrypt1/Workspace/baconnet-space/hello-craftos'
craftos_dest_path='/workspace'
readonly = true

-- equivalent to shell: unmount <craftos_dest_path>
print(('Unmounting %s'):format(craftos_dest_path));
mounter.unmount(craftos_dest_path);

-- equivalent to shell: mount <craftos_dest_path> <local_source_path>
print(('Mounting %s => %s'):format(local_source_path, craftos_dest_path));
print(('Is Readonly: %s'):format(readonly));
mounter.mount(craftos_dest_path, local_source_path, readonly);