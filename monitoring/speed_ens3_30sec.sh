#!/bin/bash

INTERVAL=30

# Получаем начальное количество байт
RX_BYTES_START=$(cat /proc/net/dev | grep ens3 | awk '{print $2}')
TX_BYTES_START=$(cat /proc/net/dev | grep ens3 | awk '{print $10}')

# Ждём
sleep $INTERVAL

# Получаем конечное количество байт
RX_BYTES_END=$(cat /proc/net/dev | grep ens3 | awk '{print $2}')
TX_BYTES_END=$(cat /proc/net/dev | grep ens3 | awk '{print $10}')

# Рассчитываем скорость (байты/сек → Мбит/с)
RX_BYTES=($RX_BYTES_END - $RX_BYTES_START)
RX_SPEED=$(( ($RX_BYTES_END - $RX_BYTES_START) / $INTERVAL * 8 / 1000000 ))
TX_SPEED=$(( ($TX_BYTES_END - $TX_BYTES_START) / $INTERVAL * 8 / 1000000 ))

echo "Средняя скорость за $INTERVAL сек: RX = $RX_SPEED Мбит/с, TX = $TX_SPEED Мбит/с"
