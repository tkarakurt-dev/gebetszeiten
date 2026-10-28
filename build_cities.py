# Erzeugt cities.json: IGMG-Städte (id, Name) mit Koordinaten + Zeitzone aus GeoNames cities1000
# Aufruf: python3 build_cities.py <igmg-gebetskalender.html> <cities1000.txt> <cities.json>
import re, json, sys, unicodedata
html, geo, out = sys.argv[1:4]
t = open(html).read()

def fix(s):
    try: return s.encode('latin1').decode('utf8')
    except Exception: return s

def norm(s):
    s = unicodedata.normalize('NFKD', s.lower().replace('ß', 'ss'))
    s = ''.join(c for c in s if not unicodedata.combining(c))
    return re.sub(r'[^a-z0-9]', '', s)

cities = []
for sel in ['alman_sehirleri', 'dunya_sehirleri']:
    i = t.find('id="%s"' % sel); j = t.find('</select>', i)
    for v, label in re.findall(r'<option value="([^"]*)"[^>]*>([^<]*)', t[i:j]):
        if v == 'please_choose': continue
        label = fix(label.strip())
        m = re.match(r'^(.*?)\s*\(([A-Z]{2,3})\)$', label)
        if not m: continue
        name, cc = m.group(1), m.group(2)
        base = re.sub(r'\s*\(.*?\)', '', name).strip()
        cities.append(dict(id=v, label=label, name=base, cc=cc))

idx = {}
for line in open(geo, encoding='utf8'):
    f = line.rstrip('\n').split('\t')
    cc, pop = f[8], int(f[14] or 0)
    names = {f[1], f[2]} | set(f[3].split(',')[:60] if f[3] else [])
    for n in names:
        k = (cc, norm(n))
        main = n in (f[1], f[2])
        cur = idx.get(k)
        score = (main, pop)
        if cur is None or score > cur[0]:
            idx[k] = (score, float(f[4]), float(f[5]), f[17])

# IGMG nutzt teils eigene Ländercodes
ccmap = {'UK': 'GB', 'TR': 'TR', 'KOS': 'XK', 'KO': 'XK'}
res, miss = [], []
for c in cities:
    cc = ccmap.get(c['cc'], c['cc'])
    hit = idx.get((cc, norm(c['name']))) or idx.get((cc, norm(c['label'].rsplit('(', 1)[0])))
    if not hit:
        miss.append(c['label'])
        # ohne Koordinaten trotzdem manuell wählbar; Zeitzone für DE bekannt
        res.append([c['id'], c['label'], None, None, 'Europe/Berlin' if c['cc'] == 'DE' else None]); continue
    res.append([c['id'], c['label'], round(hit[1], 4), round(hit[2], 4), hit[3]])
json.dump(res, open(out, 'w'), ensure_ascii=False, separators=(',', ':'))
de = [c for c in cities if c['cc'] == 'DE']
print('gesamt', len(cities), 'ohne Koordinaten', len(miss))
print('DE fehlend', sum(1 for m in miss if m.endswith('(DE)')), 'von', len(de))
print([m for m in miss if m.endswith('(DE)')][:25])
print(miss[:15])
