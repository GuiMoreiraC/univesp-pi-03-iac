import boto3  # type: ignore
import csv
import json
import os
import re
import unicodedata
from io import StringIO

def normalize_text(text: str) -> str:
    """Remove acentos, espaços e hífens; converte para lowercase."""
    return (unicodedata.normalize('NFKD', text)
            .encode('ASCII', 'ignore')
            .decode('ASCII')
            .lower()
            .replace(' ', '')
            .replace('-', ''))

def infer_ano_from_subfolder(key: str) -> int | None:
    """Extrai o ano de caminhos como '.../2025/arquivo.csv'."""
    m = re.search(r'dengue_data_raw/(20\d{2})/', key)
    return int(m.group(1)) if m else None

def _error_response(code: int, msg: str, details: str) -> dict:
    return {
        'statusCode': code,
        'body': json.dumps({'error': msg, 'details': details}, ensure_ascii=False)
    }

def lambda_handler(event, context):
    s3 = boto3.client('s3')
    bucket = os.environ.get("BUCKET_NAME", "dengue-csv-data")
    prefix = "dengue_data_raw/"
    output_key = "dengue-tratado.json"

    # 1) Tenta usar cache JSON
    try:
        obj = s3.get_object(Bucket=bucket, Key=output_key)
        treated_json = obj['Body'].read().decode('utf-8')
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': treated_json
        }
    except s3.exceptions.NoSuchKey:
        print("⚠️ JSON não encontrado no cache. Processando CSVs...")

    # 2) Lista os CSVs
    try:
        resp = s3.list_objects_v2(Bucket=bucket, Prefix=prefix)
        if 'Contents' not in resp or not resp['Contents']:
            raise ValueError(f"Nenhum arquivo .csv encontrado em {prefix}")
        keys = [o['Key'] for o in resp['Contents'] if o['Key'].lower().endswith('.csv')]
    except Exception as e:
        return _error_response(500, 'Erro ao listar arquivos', str(e))

    structured: dict = {}
    meses_validos = {
        'janeiro','fevereiro','marco','abril','maio','junho',
        'julho','agosto','setembro','outubro','novembro','dezembro'
    }

    for key in keys:
        print(f"📥 Processando {key}")
        try:
            data = s3.get_object(Bucket=bucket, Key=key)['Body'].read()
            text = data.decode('ISO-8859-1')
            lines = text.splitlines()

            # Detecta delimitador
            first = lines[0]
            delimiter = ',' if first.count(',') > first.count(';') else ';'

            # Encontra índice do cabeçalho real: deve ter coluna 'municipio' E coluna de período
            header_idx = None
            for idx, line in enumerate(lines):
                cols = line.split(delimiter)
                norm = [normalize_text(c) for c in cols]
                has_mun      = any('municipio' in c or 'nome_rs' in c for c in norm)
                has_periodo = any(
                    re.match(r'^se\d{1,2}$', c) or c in meses_validos
                    for c in norm
                )
                if has_mun and has_periodo:
                    header_idx = idx
                    break

            if header_idx is None:
                print(f"⚠️ Cabeçalho real não encontrado em {key}")
                continue

            # Prepara as linhas de dado, pulando título extra
            data_lines = lines[header_idx+1:]
            if data_lines and re.fullmatch(rf"[{delimiter}\s]*", data_lines[0]):
                data_lines = data_lines[1:]

            # Cabeçalho padrão
            raw_header = lines[header_idx]
            headers = [h.strip() for h in raw_header.split(delimiter)]

            reader = csv.DictReader(
                data_lines,
                fieldnames=headers,
                delimiter=delimiter
            )

            ano = infer_ano_from_subfolder(key) or 'desconhecido'
            print(f"📅 Ano detectado: {ano}")

            # Processa cada linha
            for row in reader:
                clean = {
                    normalize_text(k): v.strip()
                    for k, v in row.items() if k
                }

                # Detecta município dinamicamente
                municipio_key = next(
                    (k for k in clean
                     if 'municipio' in k
                        or 'munres'  in k
                        or 'nome_rs' in k),
                    None
                )
                municipio = clean.get(municipio_key) if municipio_key else None

                # Detecta código IBGE dinamicamente
                cod_key = next(
                    (k for k in clean
                     if 'codigo' in k
                        or 'codrs'  in k),
                    None
                )
                cod_ibge = clean.get(cod_key) if cod_key else None

                if not municipio:
                    print(f"⚠️ Ignorando linha sem município (buscado: {municipio_key})")
                    continue

                freq = 'mensal' if 'mes' in normalize_text(key) else 'semanal'

                # Extrai os períodos (meses ou semanas)
                for col, val in clean.items():
                    c = normalize_text(col)
                    is_periodo = (
                        re.match(r'^se\d{1,2}$', c)
                        or c in meses_validos
                    )
                    if not is_periodo:
                        continue

                    try:
                        casos = int(val)
                    except ValueError:
                        casos = 0

                    structured.setdefault(str(ano), {}) \
                              .setdefault(municipio, {}) \
                              .setdefault(freq, []) \
                              .append({
                                  'periodo': col,
                                  'casos': casos,
                                  'codigo_ibge': cod_ibge,
                                  'tipo': 'autóctone'
                              })

            print(f"✅ {key} processado")

        except Exception as e:
            return _error_response(500, f'Erro ao processar {key}', str(e))

    # 3) Salva JSON tratado de volta no S3
    try:
        s3.put_object(
            Bucket=bucket,
            Key=output_key,
            Body=json.dumps(structured, ensure_ascii=False),
            ContentType='application/json'
        )
    except Exception as e:
        return _error_response(500, 'Erro ao salvar JSON', str(e))

    return {
        'statusCode': 200,
        'headers': {'Content-Type': 'application/json'},
        'body': json.dumps({'message': 'Processamento concluído', 'arquivo': output_key}, ensure_ascii=False)
    }
