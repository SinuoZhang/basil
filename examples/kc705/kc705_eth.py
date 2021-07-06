# ------------------------------------------------------------
# SiTCP throughput test
# Reads data for a couple of seconds and displays the data rate
#
# Copyright (c) All rights reserved
# SiLab, Physics Institute, University of Bonn
# ------------------------------------------------------------
#
import logging
import time
import numpy as np
from tqdm import tqdm
from basil.dut import Dut


class KC705_Eth_Test(Dut):

    def _disable(self):
        self['CONTROL']['EN'] = 0
        self['CONTROL']['BURST'] = 0
        self['CONTROL'].write()

    def _enable(self):
        self['CONTROL']['EN'] = 1
        self['CONTROL']['BURST'] = 0
        self['CONTROL'].write()

    def _burst(self):
        self['CONTROL']['EN'] = 1
        self['CONTROL']['BURST'] = 1
        self['CONTROL'].write()

    def _flush_fifo(self):
        for i in range(10):
            temp = self['FIFO'].get_data(bytes=8)
            if len(temp) == 0:
                break

    def init(self):
        super(KC705_Eth_Test, self).init()
        self._disable()

    def test_compare(self, n=10):
        logging.info("Starting data test ...")

        start = 0
        comp_all = np.zeros(0)
        self._burst()

        for i in tqdm(range(n)):
            time.sleep(0.1)

            fifo_data = self['FIFO'].get_data(bytes=8)
            data_size = len(fifo_data)
            data_gen = np.linspace(start, data_size - 1 + start, data_size, dtype=np.int64)
            comp = fifo_data == data_gen
            np.append(comp_all, comp)
            logging.debug("%s: %.2f Mbits checked. OK?: %s" % (i, float(32 * data_size) / pow(10, 6), comp.all()))
            start += data_size

        self._disable()
        self._flush_fifo()
        logging.info("%.2f Mbits checked. OK?: %s" % (float(32 * start) / pow(10, 6), comp_all.all()))

        return comp_all.all()

    def test_throughput(self, testduration=10):
        logging.info("Starting speed test ...")

        total_len = 0
        tick = 0
        tick_old = 0
        start_time = time.time()
        self._enable()

        with tqdm(total=testduration) as pbar:
            while time.time() - start_time < testduration:
                data = self['FIFO'].get_data(bytes=8)
                total_len += len(data) * 64
                time.sleep(0.01)
                tick = int(time.time() - start_time)
                if tick != tick_old:
                    logging.debug("%.0f Mbits received in %u s" % (total_len / 1e6, tick))
                    pbar.update(1)
                    tick_old = tick

        datarate = (total_len / 1e6 / testduration)
        self._disable()
        self._flush_fifo()
        logging.info("Received: %s bytes in %u s, average data rate: %s Mbit/s" % (total_len, testduration, round(datarate, 2)))

        return datarate


if __name__ == "__main__":
    kc705 = KC705_Eth_Test(conf="kc705_eth.yaml")
    kc705.init()

    kc705.test_compare()
    kc705.test_throughput()
