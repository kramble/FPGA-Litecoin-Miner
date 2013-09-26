#!/usr/bin/env python

# by teknohog

# Python wrapper for Xilinx Serial Miner

# Host/user configuration is NOT USED in ltcminer-testmode.py

# CONFIGURATION - CHANGE THIS (eg try COM1, COM2, COM3, COM4 etc)
serial_port = "COM4"
# serial_port = "/dev/ttyUSB0"	# raspberry pi

# CONFIGURATION - how often to refresh work - reduced for testing
askrate = 2

###############################################################################

from jsonrpc import ServiceProxy
from time import ctime, sleep, time
from serial import Serial
from threading import Thread, Event
from Queue import Queue
import sys

dynclock = 0
dynclock_hex = "0000"

def stats(count, starttime):
	khshare = 65.536 * writer.diff

	s = sum(count)
	tdelta = time() - starttime
	rate = s * khshare / tdelta

	# This is only a rough estimate of the true hash rate,
	# particularly when the number of events is low. However, since
	# the events follow a Poisson distribution, we can estimate the
	# standard deviation (sqrt(n) for n events). Thus we get some idea
	# on how rough an estimate this is.

	# s should always be positive when this function is called, but
	# checking for robustness anyway
	if s > 0:
		stddev = rate / s**0.5
	else:
		stddev = 0

	return "[%i accepted, %i failed, %.2f +/- %.2f khash/s]" % (count[0], count[1], rate, stddev)

class Reader(Thread):
	def __init__(self):
		Thread.__init__(self)

		self.daemon = True

		# flush the input buffer
		ser.read(1000)

	def run(self):
		while True:
			nonce = ser.read(4)

			if len(nonce) == 4:
				# Keep this order, because writer.block will be
				# updated due to the golden event.
				submitter = Submitter(writer.block, nonce)
				submitter.start()
				golden.set()


class Writer(Thread):
	def __init__(self,dynclock_hex):
		Thread.__init__(self)

		# Keep something sensible available while waiting for the
		# first getwork
		self.block = "0" * 256
		self.target = "f" * 56 + "ff070000"		# diff=32 for testmode
		self.diff = 32	# testmode
		self.dynclock_hex = dynclock_hex

		self.daemon = True
		self.go = True
		# Alternatively use test_data_cut.txt for full 910 hash test suite
		self.infile = open("../../scripts/test_data.txt","r")
		self.nonce = 0
		self.nonce_tested = 0
		self.nonce_ok = 0
		self.nonce_fail = 0

	def run(self):
		while self.go:
			try:
				# work = bitcoin.getwork()
				# self.block = work['data']
				# self.target = work['target']
				print "Tested", self.nonce_tested, " passed", self.nonce_ok, " fail", self.nonce_fail, " unmatched", self.nonce_tested - self.nonce_ok - self.nonce_fail
				self.line = self.infile.readline()
				if (len(self.line) != 257):
					print "EOF on test data"	# Or its an error, but let's not be worrysome

					# quit()		# Except it doesn't ...
					self.go = False	# Terminating threads is a bit tricksy
					break
				self.nonce_tested = self.nonce_tested + 1
				self.block = self.line.rstrip()
				
				# Hard-code a diff=32 target for test work
				# Replace MSB 16 bits of target with clock (NB its reversed)
				self.target = "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffff07" + self.dynclock_hex
				self.dynclock_hex = "0000"	# Once only
				
				# print("block old " + self.block)
				# We need to subtract a few from the nonces in order to match (why?)
				nonce_bin = self.block.decode('hex')[79:75:-1]
				self.nonce = int(nonce_bin.encode('hex'), 16)
				# print "nonce old =", self.nonce
				nonce_new = self.nonce - 50
				if (nonce_new < 0):
					nonce_new = 0
				# print "nonce new =", nonce_new
				nonce_hex = "{0:08x}".format(nonce_new)
				# print "encoded = ", nonce_hex
				nonce_hex_rev = nonce_hex[6:8]+nonce_hex[4:6]+nonce_hex[2:4]+nonce_hex[0:2]
				# print "reversed = ", nonce_hex_rev
				self.block = self.block[0:152]+nonce_hex_rev+self.block[160:]
				# print("block new " + self.block)
			except:
				print("RPC getwork error")
				# In this case, keep crunching with the old data. It will get 
				# stale at some point, but it's better than doing nothing.

			# print("block " + self.block + " target " + self.target)	# DEBUG

			sdiff = self.target.decode('hex')[31:27:-1]
			intTarget = int(sdiff.encode('hex'), 16)
			if (intTarget < 1):
				print "WARNING zero target", intTarget
				print "target", self.target
				print("sdiff", sdiff)	# NB Need brackets here else prints binary
				self.target = "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7f0000"
			else:
				newdiff = 65536.0 / (intTarget+1)
				if (self.diff != newdiff):
					print "New target diff =", newdiff
				self.diff = newdiff

			# print("Sending data to FPGA")	# DEBUG

			# for litecoin send 80 bytes of the 128 byte data plus 4 bytes of 32 byte target
			payload = self.target.decode('hex')[31:27:-1] + self.block.decode('hex')[79::-1]
			
			# TEST HASH, this should match on nonce 0000318f
			# NB The pool will REJECT this share as it did not send the data...
			# UNCOMMENT the following two lines for testing...
			# test_payload ="000000014eb4577c82473a069ca0e95703254da62e94d1902ab6f0eae8b1e718565775af20c9ba6ced48fc9915ef01c54da2200090801b2d2afc406264d491c7dfc7b0b251e91f141b44717e00310000ff070000"
			# payload = test_payload.decode('hex')[::-1]

			# This is probably best commented out unless debugging ...
			print("Test " + payload.encode('hex_codec'))	# DEBUG
			
			ser.write(payload)
			
			result = golden.wait(askrate)

			if result:
				golden.clear()

class Submitter(Thread):
	def __init__(self, block, nonce):
		Thread.__init__(self)

		self.block = block
		self.nonce = nonce

	def run(self):
		# This thread will be created upon every submit, as they may
		# come in sooner than the submits finish.

		# print("Block found on " + ctime())
		print("Share found on " + ctime() + " nonce " + self.nonce.encode('hex_codec'))
		if (int(self.nonce.encode('hex_codec'),16) != writer.nonce):
			print "... ERROR expected nonce", hex(writer.nonce)
			writer.nonce_fail = writer.nonce_fail + 1
		else:
			print "... CORRECT"
			writer.nonce_ok = writer.nonce_ok + 1
		
		hrnonce = self.nonce[::-1].encode('hex')

		data = self.block[:152] + hrnonce + self.block[160:]

		try:
			# result = bitcoin.getwork(data)
			result = False
			# print("Upstream result: " + str(result))	# Pointless in test mode
		except:
			print("RPC send error")
			# a sensible boolean for stats
			result = False

		results_queue.put(result)

class Display_stats(Thread):
	def __init__(self):
		Thread.__init__(self)

		self.count = [0, 0]
		self.starttime = time()
		self.daemon = True

		print("Miner started on " + ctime())

	def run(self):
		while True:
			result = results_queue.get()
			
			if result:
				self.count[0] += 1
			else:
				self.count[1] += 1
				
			# print(stats(self.count, self.starttime)) 	# Pointless in test mode
				
			results_queue.task_done()

# ======= main =======

# Process command line

if (len(sys.argv) > 2):
	print "ERROR too many command line arguments"
	print "usage:", sys.argv[0], "clockfreq"
	quit()

if (len(sys.argv) == 1):
	print "WARNING no clockfreq supplied, not setting freq"
else:
	# TODO ought to check the value is a valid integer
	try:
		dynclock = int(sys.argv[1])
	except:
		print "ERROR parsing clock frequency on command line, needs to be an integer"
		print "usage:", sys.argv[0], "clockfreq"
		quit()
	if (dynclock==0):
		print "ERROR parsing clock frequency on command line, cannot be zero"
		print "usage:", sys.argv[0], "clockfreq"
		quit()
	if (dynclock>254):	# Its 254 since onescomplement(255) is zero, which is not allowed
		print "ERROR parsing clock frequency on command line, max 254"
		print "usage:", sys.argv[0], "clockfreq"
		quit()
	if (dynclock<25):
		print "ERROR use at least 25 for clock (the DCM can lock up for low values)"
		print "usage:", sys.argv[0], "clockfreq"
		quit()
	dynclock_hex = "{0:04x}".format((255-dynclock)*256+dynclock)	# both value and ones-complement
	print "INFO will set clock to", dynclock, "MHz hex", dynclock_hex

golden = Event()

# url = 'http://' + user + ':' + password + '@' + host + ':' + http_port

# bitcoin = ServiceProxy(url)

results_queue = Queue()

# default is 8 bit no parity which is fine ...
# http://pyserial.sourceforge.net/shortintro.html#opening-serial-ports

ser = Serial(serial_port, 115200, timeout=askrate)

reader = Reader()
writer = Writer(dynclock_hex)
disp = Display_stats()

reader.start()
writer.start()
disp.start()

try:
	while writer.go:
		# Threads are generally hard to interrupt. So they are left
		# running as daemons, and we do something simple here that can
		# be easily terminated to bring down the entire script.
		sleep(1)
except KeyboardInterrupt:
	print("Terminated")
