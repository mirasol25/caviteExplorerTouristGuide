require('dotenv').config();

const { PrismaClient } = require('@prisma/client');
const { randomUUID } = require('crypto');
const { mkdir, writeFile } = require('fs/promises');
const { extname, join } = require('path');

const prisma = new PrismaClient();
const uploadDirectory = join(process.cwd(), 'uploads', 'landmarks');
const verifiedBy = 'josephmirasol25@gmail.com';
const tourismSource = 'https://tourism.cavite.gov.ph/cavite-tourism-passport/';
const heritageTourSource = 'https://pia.gov.ph/news/kawit-tourism-presents-local-history-and-culture-through-heritage-tour/';
const emergencyContact = 'Emergency: 911\nKawit Municipal Disaster Risk Reduction and Management Office: confirm the current hotline with the municipal government before travel';

const churchGuidance = {
  entranceFee: '', isFreeEntrance: true, operatingStatus: 'open',
  dressCode: 'Wear modest clothing suitable for an active Catholic place of worship.',
  photographyRules: 'Personal photography is generally appropriate outside services. Ask permission before using flash, tripods, drones, or photographing ceremonies.',
  prohibitedItems: 'Do not bring food or drinks into worship areas, touch sacred objects, create excessive noise, or disrupt Mass and parish activities.',
  petPolicy: 'Pets should remain outside worship areas unless they are trained service animals or parish permission is given.',
  emergencyContact,
};

const outdoorGuidance = {
  entranceFee: '', isFreeEntrance: true, operatingStatus: 'open',
  dressCode: 'Wear comfortable, weather-appropriate clothing and walking shoes.',
  photographyRules: 'Personal photography is generally appropriate. Do not block roads or paths; drones and commercial shoots require permission.',
  prohibitedItems: 'Do not litter, climb monuments, vandalize markers, or enter restricted areas.',
  petPolicy: 'Keep pets leashed and supervised and clean up after them.',
  emergencyContact,
};

const records = [
  {
    name: 'Museo ni Emilio Aguinaldo and Freedom Park',
    aliases: ['Aguinaldo Shrine', 'Emilio Aguinaldo Shrine', 'Museo ni Emilio Aguinaldo', 'Aguinaldo Shrine and Freedom Park'],
    imageUrls: ['https://commons.wikimedia.org/wiki/Special:Redirect/file/Aguinaldo%20Shrine%20at%20Kawit%2C%20Cavite.jpg'],
    data: {
      shortSummary: 'The ancestral home of Emilio Aguinaldo and the nationally significant site where Philippine independence was proclaimed on June 12, 1898.',
      municipality: 'Kawit', barangay: 'Kaingen', streetAddress: 'Kawit Loop Road / Tirona Highway, Barangay Kaingen, Kawit, Cavite 4104',
      description: 'Museo ni Emilio Aguinaldo preserves the mansion, personal objects, historic rooms, tomb, and grounds associated with General Emilio Aguinaldo. Its balcony is inseparable from the national memory of the proclamation of Philippine independence, while the surrounding Freedom Park provides space for monuments, ceremonies, and public reflection.',
      category: 'Museum / National Shrine', latitude: 14.4450003, longitude: 120.9068957,
      openingDays: 'Tuesday to Sunday; confirm the current museum schedule before traveling', openingTime: '', closingTime: '', isAlwaysOpen: false,
      entranceFee: '', isFreeEntrance: true, contactNumber: '(046) 484-7643', websiteUrl: 'https://philhistoricsites.nhcp.gov.ph/registry_database/emilio-aguinaldo-shrine/',
      visitDuration: '1 to 2 hours', bestTimeToVisit: 'Weekday morning; June 12 is historically meaningful but normally crowded', operatingStatus: 'open',
      historicalBackground: 'The Aguinaldo family house dates to the nineteenth century and was expanded over time under Emilio Aguinaldo. On June 12, 1898, Philippine independence from Spain was proclaimed from the house. Ambrosio Rianzares Bautista read the Act of the Declaration of Independence, the Philippine flag made by Marcela Agoncillo and her companions was formally unfurled, and Julian Felipe’s Marcha Nacional Filipina was played. Aguinaldo later donated the property to the government, and it became a national shrine and public museum administered by the National Historical Commission of the Philippines.',
      culturalSignificance: 'This is one of the Philippines’ most important places of national memory. It connects Kawit directly to independence, the birth of the republic, the national flag, national anthem, and the life of the country’s first president.',
      yearEstablished: 'House begun in the 1840s; independence proclaimed in 1898; national shrine since 1964',
      importantPeople: ['Emilio Aguinaldo', 'Ambrosio Rianzares Bautista', 'Marcela Agoncillo', 'Lorenza Agoncillo', 'Delfina Herbosa de Natividad', 'Julian Felipe'],
      importantEvents: ['June 12, 1898 – Philippine independence was proclaimed.', 'The Philippine flag was formally unfurled and Marcha Nacional Filipina was played.', '1964 – The house became a national shrine after Aguinaldo’s death.'],
      interestingFacts: ['The house contains concealed passages, symbolic decorative details, and period furniture.', 'Emilio Aguinaldo is buried on the grounds.', 'The museum and Freedom Park are stops on Kawit’s official heritage tour.'],
      informationSources: ['https://philhistoricsites.nhcp.gov.ph/registry_database/emilio-aguinaldo-shrine/', 'https://philhistoricsites.nhcp.gov.ph/registry_database/site-of-the-proclamation-of-philippine-independence/', tourismSource, heritageTourSource, 'https://commons.wikimedia.org/wiki/File:Aguinaldo_Shrine_at_Kawit,_Cavite.jpg'],
      dressCode: 'Wear comfortable, respectful clothing and shoes suitable for stairs and museum floors.',
      photographyRules: 'Follow posted NHCP rules. Flash, tripods, drones, and commercial shoots may require prior permission; some interior rooms may restrict photography.',
      prohibitedItems: 'Do not touch artifacts, cross barriers, bring food or drinks into galleries, smoke, or disturb commemorative activities.',
      petPolicy: 'Pets are generally unsuitable inside museum galleries except trained service animals; ask staff about the outdoor grounds.',
      safetyReminders: 'Use handrails on narrow stairs, supervise children, and take care around road crossings and crowded ceremonies.', emergencyContact,
      visitorTips: 'Start at the visitor entrance and allow time for both the house museum and Freedom Park. Confirm opening hours for holidays and June 12 activities.',
      publicationStatus: 'published', verifiedBy,
    },
  },
  {
    name: 'Diocesan Shrine and Parish of St. Mary Magdalene',
    aliases: ['Kawit Church', 'Saint Mary Magdalene Parish Church', 'St. Mary Magdalene Church Kawit', 'Simbahan ng Kawit'],
    imageUrls: ['https://commons.wikimedia.org/wiki/Special:Redirect/file/KawitChurchjf1462%2002.JPG'],
    data: {
      ...churchGuidance,
      shortSummary: 'Kawit’s historic parish church, founded by Jesuits and closely associated with Emilio Aguinaldo and the town’s revolutionary history.',
      municipality: 'Kawit', barangay: 'Poblacion', streetAddress: 'Tirona Highway, Poblacion, Kawit, Cavite 4104',
      description: 'The Diocesan Shrine and Parish of St. Mary Magdalene is the historic Catholic center of Kawit. Its old masonry church, heritage marker, religious art, and association with Emilio Aguinaldo make it both an active place of worship and an important stop in the municipality’s heritage landscape.',
      category: 'Church / Religious Site', latitude: 14.4447435, longitude: 120.9035424,
      openingDays: 'Monday to Sunday; access may be limited during Masses, rites, and parish activities', openingTime: '', closingTime: '', isAlwaysOpen: false,
      contactNumber: '(046) 484-7485', websiteUrl: 'https://www.dioceseofimus.org/public/parishes/25', visitDuration: '30 minutes to 1 hour', bestTimeToVisit: 'Outside scheduled liturgies; parish feast is July 22',
      historicalBackground: 'Jesuits began serving Kawit in 1624, and a first wooden church dedicated to Mary Magdalene was built in 1638. The cornerstone of the present church was laid in 1737. Its roof was destroyed in 1831 and later repaired. Secular priests took charge in 1768, followed by the Augustinian Recollects in 1894. Emilio Aguinaldo was baptized here in 1869. The church underwent restoration in 1990.',
      culturalSignificance: 'The church is Kawit’s mother parish and a living center of faith, community memory, and local identity. Its link to Aguinaldo and the revolutionary landscape gives it national as well as religious importance.',
      yearEstablished: 'Jesuit mission in 1624; first wooden church in 1638; present church begun in 1737',
      importantPeople: ['Emilio Aguinaldo', 'Jesuit missionaries', 'Augustinian Recollect missionaries', 'St. Mary Magdalene'],
      importantEvents: ['1624 – Jesuits began the Kawit mission.', '1638 – First wooden church was built.', '1737 – Cornerstone of the present church was laid.', '1869 – Emilio Aguinaldo was baptized here.', '1990 – Major restoration was completed.'],
      interestingFacts: ['The church is one of the oldest documented parishes in Cavite.', 'Its patronal feast is celebrated on July 22.', 'The Candido Tirona monument stands immediately beside the church complex.'],
      informationSources: ['https://philhistoricsites.nhcp.gov.ph/registry_database/simbahan-ng-kawit/', 'https://www.dioceseofimus.org/public/parishes/25', tourismSource, heritageTourSource, 'https://commons.wikimedia.org/wiki/File:KawitChurchjf1462_02.JPG'],
      safetyReminders: 'Use pedestrian crossings along Tirona Highway and watch for wet floors, steps, candles, and church traffic.',
      visitorTips: 'Keep voices low and avoid touring during Mass. Read the NHCP marker and combine the visit with the nearby Tirona monument and old municipal hall.',
      publicationStatus: 'published', verifiedBy,
    },
  },
  {
    name: 'Museo ni Baldomero Aguinaldo',
    aliases: ['Baldomero Aguinaldo Museum', 'Baldomero Aguinaldo Shrine', 'Baldomero Aguinaldo Ancestral House', 'Bahay ni Heneral Baldomero Aguinaldo'],
    imageUrls: ['https://upload.wikimedia.org/wikipedia/commons/thumb/9/92/Baldomero_Aguinaldo_Ancestral_House%2C_Kawit%2C_Cavite%2C_Aug_2025_%281%29.jpg/1920px-Baldomero_Aguinaldo_Ancestral_House%2C_Kawit%2C_Cavite%2C_Aug_2025_%281%29.jpg'],
    data: {
      shortSummary: 'The restored 1906 ancestral house of revolutionary leader Baldomero Aguinaldo, now an NHCP museum and National Historical Landmark.',
      municipality: 'Kawit', barangay: 'Tramo-Bantayan', streetAddress: 'General Flaviano Yengco Street, Tramo-Bantayan, Binakayan, Kawit, Cavite 4104',
      description: 'Museo ni Baldomero Aguinaldo is a restored early twentieth-century bahay na bato that interprets the life of General Baldomero Aguinaldo and his family. Visitors can appreciate its narra and molave construction, period rooms, family objects, historical exhibits, marker, and the burial site associated with the Aguinaldo family.',
      category: 'Museum / Ancestral House', latitude: 14.4477689, longitude: 120.9236765,
      openingDays: 'Tuesday to Sunday; confirm the current museum schedule before traveling', openingTime: '', closingTime: '', isAlwaysOpen: false,
      entranceFee: '', isFreeEntrance: true, contactNumber: '(046) 434-5983', websiteUrl: 'https://philhistoricsites.nhcp.gov.ph/registry_database/ang-bahay-ni-heneral-baldomero-aguinaldo/', visitDuration: '45 minutes to 1 hour', bestTimeToVisit: 'Weekday morning with the museum schedule confirmed', operatingStatus: 'open',
      historicalBackground: 'Baldomero Aguinaldo had the house built in 1906 using durable narra and molave. He was a leading Magdalo revolutionary, public official, and cousin of Emilio Aguinaldo. The Intramuros Administration restored the house, and Prime Minister Cesar E. A. Virata donated it to the Philippine government in 1982. A historical marker was installed in 1983, and the property is now an NHCP museum and Level I National Historical Landmark.',
      culturalSignificance: 'The museum broadens Kawit’s revolutionary story beyond Emilio Aguinaldo by presenting Baldomero’s military, political, and civic service and preserving a notable ancestral house.',
      yearEstablished: 'House built in 1906; donated in 1982; historical marker installed in 1983',
      importantPeople: ['Baldomero Aguinaldo', 'Petrona Reyes', 'Emilio Aguinaldo', 'Cesar E. A. Virata'],
      importantEvents: ['1896 – Baldomero became president of the Magdalo council.', '1897 – He served in the revolutionary government and signed the Biak-na-Bato Constitution.', '1906 – The ancestral house was built.', '1982 – The property was donated to the government.', '1983 – The historical marker was installed.'],
      interestingFacts: ['Baldomero served as finance secretary, secretary of war and public works, and commanding general of Southern Luzon.', 'He founded a veterans’ organization in 1912.', 'The house is built primarily of narra and molave.'],
      informationSources: ['https://philhistoricsites.nhcp.gov.ph/registry_database/ang-bahay-ni-heneral-baldomero-aguinaldo/', 'https://philhistoricsites.nhcp.gov.ph/registry_database/hen-baldomero-aguinaldo-y-baloy-1869-1915/', tourismSource, heritageTourSource, 'https://commons.wikimedia.org/wiki/Category:Baldomero_Aguinaldo_House'],
      dressCode: 'Wear comfortable, respectful clothing and footwear suitable for historic floors and stairs.',
      photographyRules: 'Follow museum staff and posted rules. Flash, tripods, drones, and commercial photography may require permission.',
      prohibitedItems: 'Do not touch artifacts, cross barriers, bring food or drinks into exhibit rooms, smoke, or enter staff-only areas.',
      petPolicy: 'Pets are generally unsuitable inside the museum except trained service animals.',
      safetyReminders: 'Use handrails, supervise children, and take care on historic floors and steps.', emergencyContact,
      visitorTips: 'Contact the museum before traveling and allow time to read both the house and Baldomero historical markers.',
      publicationStatus: 'published', verifiedBy,
    },
  },
  {
    name: 'Battle of Binakayan Monument',
    aliases: ['Battle of Binakayan Shrine', 'Labanan sa Binakayan Monument', 'Binakayan Monument'],
    imageUrls: ['https://upload.wikimedia.org/wikipedia/commons/thumb/9/99/Battle_of_Binakayan_Monument_and_NHCP_Historical_Marker.jpg/1920px-Battle_of_Binakayan_Monument_and_NHCP_Historical_Marker.jpg'],
    data: {
      ...outdoorGuidance,
      shortSummary: 'A monument and NHCP marker commemorating the Filipino victory at Binakayan during the Philippine Revolution in November 1896.',
      municipality: 'Kawit', barangay: 'Pulvorista', streetAddress: 'Covelandia Road near Samala Street, Pulvorista, Binakayan, Kawit, Cavite 4104',
      description: 'The Battle of Binakayan Monument marks the area associated with the November 1896 fighting in which Filipino revolutionary forces defeated a major Spanish offensive. The monument and historical marker help visitors locate and understand one of the revolution’s decisive early victories.',
      category: 'Historical Monument', latitude: 14.458943, longitude: 120.9223788,
      openingDays: 'Viewable daily from the public roadside; access may be affected by traffic or local works', openingTime: '', closingTime: '', isAlwaysOpen: true,
      websiteUrl: 'https://philhistoricsites.nhcp.gov.ph/registry_database/labanan-sa-binakayan/', visitDuration: '15 to 30 minutes', bestTimeToVisit: 'Daylight hours, preferably outside peak traffic',
      historicalBackground: 'From November 9 to 11, 1896, revolutionary forces in the Binakayan–Dalahican area resisted the Spanish offensive ordered by Governor-General Ramon Blanco. Emilio Aguinaldo commanded Filipino forces at Binakayan. The victory strengthened the revolution in Cavite, though leaders including Candido Tirona and Simeon Alcantara died in the fighting. The historical marker was installed for the battle’s centennial period.',
      culturalSignificance: 'The battle demonstrated the organization and determination of Cavite’s revolutionary forces and became one of the most important early Filipino victories of the Philippine Revolution.',
      yearEstablished: 'Battle fought November 9–11, 1896; marker installed during the centennial period',
      importantPeople: ['Emilio Aguinaldo', 'Candido Tria Tirona', 'Simeon Alcantara', 'Ramon Blanco'],
      importantEvents: ['November 9–11, 1896 – Battle of Binakayan–Dalahican.', 'Filipino forces stopped the Spanish attempt to retake revolutionary positions.', 'Candido Tirona and Simeon Alcantara died in the fighting.'],
      interestingFacts: ['The battle occurred alongside fighting at Dalahican in nearby Noveleta.', 'It was among the revolution’s first major battlefield victories.', 'The monument is part of Kawit’s official heritage-tour itinerary.'],
      informationSources: ['https://philhistoricsites.nhcp.gov.ph/registry_database/labanan-sa-binakayan/', heritageTourSource, 'https://commons.wikimedia.org/wiki/File:Battle_of_Binakayan_Monument_and_NHCP_Historical_Marker.jpg'],
      safetyReminders: 'The site is beside active roads. Stay on the safe pedestrian area, supervise children, and do not step into traffic for photographs.',
      visitorTips: 'Read the marker in daylight and pair the stop with Museo ni Baldomero Aguinaldo and the Fatima shrine in Binakayan.',
      publicationStatus: 'published', verifiedBy,
    },
  },
  {
    name: 'Diocesan Shrine and Parish of Our Lady of Fatima',
    aliases: ['Our Lady of Fatima Parish Church Binakayan', 'Binakayan Church', 'Fatima Shrine Binakayan', 'Nuestra Señora del Rosario de Fatima de Binakayan'],
    imageUrls: ['https://upload.wikimedia.org/wikipedia/commons/thumb/7/71/Our_Lady_of_Fatima_Church%2C_Binakayan.JPG/1920px-Our_Lady_of_Fatima_Church%2C_Binakayan.JPG'],
    data: {
      ...churchGuidance,
      shortSummary: 'Binakayan’s diocesan shrine and home of the pontifically crowned image locally cherished as “Imang,” Our Lady of Fatima.',
      municipality: 'Kawit', barangay: 'Samala-Marquez', streetAddress: 'Fatima Street, Samala-Marquez, Binakayan, Kawit, Cavite 4104',
      description: 'The Diocesan Shrine and Parish of Our Lady of Fatima is a major Marian pilgrimage church in Binakayan. It houses the venerated image of Nuestra Señora del Rosario de Fatima de Binakayan, affectionately called Imang, and remains an active center of parish life, devotion, and community celebrations.',
      category: 'Church / Religious Site', latitude: 14.4537988, longitude: 120.9252226,
      openingDays: 'Monday to Sunday; access may be limited during Masses, rites, and parish activities', openingTime: '', closingTime: '', isAlwaysOpen: false,
      contactNumber: '', websiteUrl: 'https://www.dioceseofimus.org/', visitDuration: '30 minutes to 1 hour', bestTimeToVisit: 'Outside scheduled liturgies; May celebrations may be crowded',
      historicalBackground: 'Binakayan was formerly served by St. Mary Magdalene Parish. The Our Lady of Fatima parish was formally established on May 13, 1966 under Father Luciano Paguiligan. A devotional image from Portugal was donated by Eugene and Geraldine Conolly of New York. The church later became a diocesan shrine. Pope Francis authorized a pontifical coronation in October 2024, and the coronation was celebrated on May 1, 2025.',
      culturalSignificance: 'The shrine expresses Binakayan’s strong Marian devotion and serves as one of Kawit’s principal pilgrimage destinations. The locally beloved image of Imang was recognized by the municipal government as Mother and Queen of Kawit.',
      yearEstablished: 'Parish established May 13, 1966; pontifical coronation celebrated May 1, 2025',
      importantPeople: ['Our Lady of Fatima (Imang)', 'Father Luciano Paguiligan', 'Eugene and Geraldine Conolly', 'Pope Francis', 'Archbishop Charles John Brown', 'Bishop Reynaldo G. Evangelista'],
      importantEvents: ['May 13, 1966 – Parish formally established.', 'The image from Portugal became the focus of local devotion.', 'October 15, 2024 – Pontifical coronation was authorized.', 'May 1, 2025 – Pontifical coronation was celebrated.'],
      interestingFacts: ['The image is affectionately called Imang by devotees.', 'The parish began as part of the older St. Mary Magdalene mother parish.', 'It is included in the Cavite Tourism Passport’s faith-tourism destinations.'],
      informationSources: ['https://www.dioceseofimus.org/news/ang-mahal-na-imang-birhen-ng-fatima-koronada-na-pontifical-coronation-01jtfc3qrenhgvc813q33ednmr', 'https://dioceseofimus.org/vicariates/4', tourismSource, 'https://commons.wikimedia.org/wiki/File:Our_Lady_of_Fatima_Church,_Binakayan.JPG'],
      safetyReminders: 'Use pedestrian paths, supervise children, and watch for candles, steps, wet floors, and heavy crowds during feast days.',
      visitorTips: 'Visit quietly outside services and verify the current Mass and shrine schedule through the parish or Diocese of Imus.',
      publicationStatus: 'published', verifiedBy,
    },
  },
  {
    name: 'General Candido Tria Tirona Monument',
    aliases: ['Candido Tirona Monument', 'General Candido Tirona Historical Marker', 'Heneral Candido Tria Tirona Monument'],
    imageUrls: ['https://upload.wikimedia.org/wikipedia/commons/thumb/5/5a/Candido_Tria_Tirona_statue_outside_Kawit_Church_-_2.jpg/1920px-Candido_Tria_Tirona_statue_outside_Kawit_Church_-_2.jpg'],
    data: {
      ...outdoorGuidance,
      shortSummary: 'A monument beside Kawit Church honoring Magdalo revolutionary leader General Candido Tria Tirona.',
      municipality: 'Kawit', barangay: 'Poblacion', streetAddress: 'Beside St. Mary Magdalene Church, Tirona Highway, Poblacion, Kawit, Cavite 4104',
      description: 'The General Candido Tria Tirona Monument and historical marker honor the Kawit-born revolutionary who helped spread the Katipunan in Cavite, served as the Magdalo council’s secretary of war, and died during the Battle of Binakayan.',
      category: 'Monument / Memorial', latitude: 14.44462, longitude: 120.90334,
      openingDays: 'Viewable daily from the public area beside the church', openingTime: '', closingTime: '', isAlwaysOpen: true,
      websiteUrl: 'https://philhistoricsites.nhcp.gov.ph/registry_database/heneral-candido-tria-tirona/', visitDuration: '10 to 20 minutes', bestTimeToVisit: 'Daylight hours outside church-service traffic',
      historicalBackground: 'Candido Tria Tirona was born in Kawit on August 29, 1862. He helped organize and spread the Katipunan in Cavite, joined Emilio Aguinaldo in the first attack on Spanish positions in Kawit, and became secretary of war of the Magdalo council. He was killed in the Battle of Binakayan on November 10, 1896. A government historical marker honoring him was installed in 1956.',
      culturalSignificance: 'The monument preserves the memory of a locally born revolutionary leader whose sacrifice connects Kawit’s town center with the nearby Binakayan battlefield.',
      yearEstablished: 'Historical marker installed in 1956',
      importantPeople: ['Candido Tria Tirona', 'Emilio Aguinaldo', 'Estanislao Tirona', 'Juana Mata'],
      importantEvents: ['August 29, 1862 – Candido Tirona was born in Kawit.', '1896 – He helped lead Magdalo revolutionary activity.', 'November 10, 1896 – He died in the Battle of Binakayan.', '1956 – Historical marker installed.'],
      interestingFacts: ['Kawit’s main highway bears the Tirona name.', 'The monument stands beside the same historic church complex associated with Emilio Aguinaldo.', 'The marker identifies Tirona as patriot, revolutionary, and hero.'],
      informationSources: ['https://philhistoricsites.nhcp.gov.ph/registry_database/heneral-candido-tria-tirona/', 'https://commons.wikimedia.org/wiki/File:Candido_Tria_Tirona_statue_outside_Kawit_Church_-_2.jpg'],
      safetyReminders: 'Remain on the pedestrian area and watch for vehicles entering the church and passing on Tirona Highway.',
      visitorTips: 'Combine this short stop with St. Mary Magdalene Church and the Old Kawit Municipal Hall marker.',
      publicationStatus: 'published', verifiedBy,
    },
  },
  {
    name: 'Old Kawit Municipal Hall and Historical Marker',
    aliases: ['Old Kawit Municipal Hall', 'Pamahalaang Bayan ng Kawit 1896', 'Kawit Municipal Hall Historical Marker'],
    imageUrls: ['https://upload.wikimedia.org/wikipedia/commons/thumb/9/9e/Kawit_Municipal_Hall_historical_marker.JPG/1920px-Kawit_Municipal_Hall_historical_marker.JPG'],
    data: {
      ...outdoorGuidance,
      shortSummary: 'The old municipal-government site where Kawit Katipuneros launched the Cavite Revolution on August 31, 1896.',
      municipality: 'Kawit', barangay: 'Poblacion', streetAddress: 'Tirona Highway, Poblacion, Kawit, Cavite 4104',
      description: 'The Old Kawit Municipal Hall site and NHCP historical marker identify the former town-government building attacked by Cavite Katipuneros under Emilio Aguinaldo and Candido Tirona. The event is remembered as the beginning of the revolution in Cavite province.',
      category: 'Historical Marker', latitude: 14.4443113, longitude: 120.9033233,
      openingDays: 'Exterior marker viewable daily from the public area', openingTime: '', closingTime: '', isAlwaysOpen: true,
      websiteUrl: 'https://philhistoricsites.nhcp.gov.ph/registry_database/pamahalaang-bayan-ng-kawit-1896/', visitDuration: '10 to 20 minutes', bestTimeToVisit: 'Daylight hours outside peak road traffic',
      historicalBackground: 'On the afternoon of August 31, 1896, Cavite Katipuneros led by Emilio Aguinaldo and Candido Tria Tirona besieged the municipal-government building that formerly stood at this site. The action marked the outbreak of the Philippine Revolution in Cavite. The National Historical Institute installed the marker in 1973.',
      culturalSignificance: 'The site anchors Kawit’s local revolutionary story in the civic center and explains how the uprising spread into Cavite shortly after the Cry near Manila.',
      yearEstablished: 'Historic event on August 31, 1896; marker installed in 1973',
      importantPeople: ['Emilio Aguinaldo', 'Candido Tria Tirona', 'Katipuneros of Cavite'],
      importantEvents: ['August 31, 1896 – Katipuneros besieged the old municipal building.', 'The action began the revolution in Cavite province.', '1973 – National Historical Institute marker installed.'],
      interestingFacts: ['The marker identifies a former building site rather than the present Kawit Municipal Hall.', 'It stands within a compact heritage cluster near Kawit Church and the Tirona monument.', 'The attack occurred before Kawit became internationally known for the 1898 independence proclamation.'],
      informationSources: ['https://philhistoricsites.nhcp.gov.ph/registry_database/pamahalaang-bayan-ng-kawit-1896/', 'https://commons.wikimedia.org/wiki/File:Kawit_Municipal_Hall_historical_marker.JPG'],
      safetyReminders: 'Stay on the pedestrian side of the road and avoid blocking building entrances or traffic while reading or photographing the marker.',
      visitorTips: 'Look specifically for the NHCP plaque and do not confuse this historic site with Kawit’s present municipal hall in Batong Dalig.',
      publicationStatus: 'published', verifiedBy,
    },
  },
];

function extensionFor(url, contentType) {
  const extension = extname(new URL(url).pathname).toLowerCase();
  if (['.jpg', '.jpeg', '.png', '.webp'].includes(extension)) return extension === '.jpeg' ? '.jpg' : extension;
  if (contentType.includes('png')) return '.png';
  if (contentType.includes('webp')) return '.webp';
  return '.jpg';
}

async function downloadImages(urls) {
  const paths = [];
  await mkdir(uploadDirectory, { recursive: true });
  for (const url of urls) {
    try {
      let response;
      for (let attempt = 1; attempt <= 3; attempt += 1) {
        response = await fetch(url, { redirect: 'follow', headers: { 'User-Agent': 'CaviteExplorer/1.0 (landmark data import)' } });
        if (response.status !== 429 || attempt === 3) break;
        await new Promise((resolve) => setTimeout(resolve, attempt * 4000));
      }
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const contentType = response.headers.get('content-type') || '';
      if (!contentType.startsWith('image/')) throw new Error(`Unexpected content type ${contentType}`);
      const filename = `${randomUUID()}${extensionFor(response.url || url, contentType)}`;
      await writeFile(join(uploadDirectory, filename), Buffer.from(await response.arrayBuffer()));
      paths.push(`/uploads/landmarks/${filename}`);
      await new Promise((resolve) => setTimeout(resolve, 2500));
    } catch (error) {
      console.warn(`Image skipped (${url}): ${error.message}`);
    }
  }
  return paths;
}

async function upsertRecord(record) {
  const names = [record.name, ...(record.aliases || [])];
  const matches = await prisma.landmark.findMany({
    where: { municipality: { equals: 'Kawit', mode: 'insensitive' }, name: { in: names } },
    orderBy: { createdAt: 'asc' },
  });
  const preferred = matches.find((item) => item.name === record.name) || matches[0];
  const images = preferred?.images?.length ? preferred.images : await downloadImages(record.imageUrls || []);
  const now = new Date();
  const data = { ...record.data, name: record.name, images, lastVerifiedAt: now, publishedAt: preferred?.publishedAt || now };
  const saved = preferred
    ? await prisma.landmark.update({ where: { id: preferred.id }, data })
    : await prisma.landmark.create({ data });

  for (const duplicate of matches.filter((item) => item.id !== saved.id)) {
    await prisma.landmark.update({ where: { id: duplicate.id }, data: { publicationStatus: 'archived' } });
  }
  console.log(`${preferred ? 'Updated' : 'Created'}: ${saved.name} (${saved.images.length} image${saved.images.length === 1 ? '' : 's'})`);
}

async function main() {
  for (const record of records) await upsertRecord(record);
  const officialNames = records.map((record) => record.name);
  const completed = await prisma.landmark.findMany({
    where: { municipality: 'Kawit', name: { in: officialNames }, publicationStatus: 'published' },
    select: { name: true, barangay: true, category: true, images: true },
    orderBy: { name: 'asc' },
  });
  console.log(`\nPublished Kawit heritage and tourism sites: ${completed.length}/${officialNames.length}`);
  for (const place of completed) console.log(`- ${place.name} | ${place.barangay} | ${place.category} | ${place.images.length} image(s)`);
  if (completed.length !== officialNames.length || completed.some((place) => place.images.length === 0)) process.exitCode = 1;
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}).finally(async () => {
  await prisma.$disconnect();
});
