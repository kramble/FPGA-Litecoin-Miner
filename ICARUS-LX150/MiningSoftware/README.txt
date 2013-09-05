Mining software for ltcminer.

You will need to install python 2.7, then ...

From the fpgaminer/project/Verilog_Xilinx_Port/README.txt I quote ...
  It requires a few non-standard libraries, pyserial and json-rpc.
  http://pyserial.sourceforge.net/
  (also generally available in Linux distributions)
  http://json-rpc.org/wiki/python-json-rpc

Since these are open source, I have included them in the MiningSoftware folder, vis

pyserial-2.6 from http://pyserial.sourceforge.net
python-json-rpc from http://json-rpc.org/browser/trunk/python-jsonrpc/jsonrpc

To install them run "python setup.py install" in each folder (sudo if on linux)

Edit ltcminer.py and set the serial port to match your system (eg COM2) plus
your pool url, worker name and worker password. You can also change the baudrate
but this must match the value hard-coded into ltcminer_icarus.v

There is a test getwork that you can enable, just uncomment the two lines for
test_payload. This still requires a working pool, which will REJECT the share, but
its a useful quick test that everything is working. You may want to comment
out the share submission at line 140 "result = bitcoin.getwork(data)". Replace it
with "result=1" to avoid errors (NB this is just for TESTING).

Be careful of spaces/tabs in python as these are part of the syntax! If you run
into problems making changes, just copy a previous line EXACTLY, then modify the part
after the initial spaces/tabs. ADDENDUM. I have now tabbified the script with tabstop=4
(using Notepad++) which should make it much easier to edit.

When using a stratum proxy server, follow the instructions at ...
https://www.litecoinpool.org/help

Specifically you must use the version from ...
https://github.com/CryptoManiac/stratum-mining-proxy

Start it as follows (on linux) ...
./mining_proxy.py -nm -pa scrypt -o litecoinpool.org -p 3333

Or in background with ...
nohup ./mining_proxy.py -nm -pa scrypt -o litecoinpool.org -p 3333 >/tmp/stratum_ltc.log 2>&1&
