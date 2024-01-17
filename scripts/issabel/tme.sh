#!/bin/bash

# Verifica se foi fornecido um argumento
if [ -z "$1" ]; then
  echo "Por favor, forneça um argumento (hour ou day)."
  exit 1
fi

# Argumento passado para o script
opcao="$1"

# Executa a query de atualização independentemente do argumento
#mysql -N -h localhost -u asteriskuser -ppassword -D asteriskcdrdb -e "
#  UPDATE queue_log
#  SET
#    data1 = CAST(SUBSTRING_INDEX(data, '|', -1) AS UNSIGNED),
#    data2 = CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(data, '|', 2), '|', -1) AS UNSIGNED),
#    data3 = CAST(SUBSTRING_INDEX(data, '|', 1) AS UNSIGNED);
#"

# Executa a consulta específica com base no argumento
if [ "$opcao" == "hour" ]; then
  mysql -N -h localhost -u asteriskuser -ppassword -D asteriskcdrdb -e "
    SELECT
      COALESCE(ROUND(AVG(total_tempo_espera), 1), 0) AS media_tempo_espera
    FROM (
      SELECT
        callid,
        SUM(data1) AS total_tempo_espera
      FROM queue_log
      WHERE queue_log.event LIKE 'COMPLETE%'
        AND DATE(queue_log.time) = CURRENT_DATE
        AND EXTRACT(HOUR FROM queue_log.time) = EXTRACT(HOUR FROM CURRENT_TIMESTAMP)
        AND queue_log.queuename = '2000'
      GROUP BY callid
    ) AS unique_calls;
  "
elif [ "$opcao" == "day" ]; then
  mysql -N -h localhost -u asteriskuser -ppassword -D asteriskcdrdb -e "
    SELECT
      COALESCE(ROUND(AVG(total_tempo_espera), 1), 0) AS media_tempo_espera
    FROM (
      SELECT
        callid,
        SUM(data1) AS total_tempo_espera
      FROM queue_log
      WHERE queue_log.event LIKE 'COMPLETE%'
        AND DATE(queue_log.time) = CURRENT_DATE
        AND queue_log.queuename = '2000'
      GROUP BY callid
    ) AS unique_calls;
  "
else
  echo "Argumento inválido. Escolha hour ou day."
  exit 1
fi
