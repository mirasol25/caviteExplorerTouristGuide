require('dotenv').config();

const { PrismaClient } = require('@prisma/client');
const { randomUUID } = require('crypto');
const { mkdir, writeFile } = require('fs/promises');
const { extname, join } = require('path');

const prisma = new PrismaClient();
const uploadDirectory = join(process.cwd(), 'uploads', 'landmarks');
const citySource = 'https://www.cityofimus.gov.ph/historyandculture';
const tourismSource = 'https://cityofimus.gov.ph/departments_units/city_tourism';
const tourismContact = '(046) 418-6139';
const emergencyContact = 'City of Imus Emergency: (046) 888-9911\nCDRRMO: (046) 472-2618 / (046) 472-2623 / (046) 472-2625\nImus PNP: 0998-598-5601 or 911';
const verifiedBy = 'josephmirasol25@gmail.com';

const commonOutdoor = {
  openingDays: 'Open-air site; access may change during ceremonies, maintenance, or severe weather',
  openingTime: '', closingTime: '', isAlwaysOpen: true,
  entranceFee: '', isFreeEntrance: true,
  contactNumber: tourismContact, operatingStatus: 'open',
  dressCode: 'Wear comfortable, weather-appropriate clothing and walking shoes.',
  photographyRules: 'Personal photography is generally appropriate. Do not obstruct ceremonies, traffic, or other visitors; ask permission before using drones or professional equipment.',
  prohibitedItems: 'Do not litter, vandalize or climb monuments, enter restricted areas, consume alcohol, or create excessive noise.',
  petPolicy: 'No official pet policy is published. Keep pets leashed and supervised and clean up after them.',
  emergencyContact,
};

const records = [
  {
    ...commonOutdoor,
    name: 'Imus Heritage Park (Shrine of the National Flag)',
    aliases: ['Imus Heritage Park', 'Shrine of the National Flag', 'Dambana ng Pambansang Watawat', 'Shrine of the National Flag of the Philippines'],
    imageUrls: [
      'https://commons.wikimedia.org/wiki/Special:Redirect/file/Imus%20Heritage%20Park.jpg',
      'https://www.cityofimus.gov.ph/Media/Battle%20of%20Alapan%20-%20.jpg',
    ],
    data: {
      ...commonOutdoor,
      shortSummary: 'A National Historical Landmark commemorating the Battle of Alapan and the first victorious unfurling of the Philippine flag in 1898.',
      municipality: 'Imus', barangay: 'Alapan II-A', streetAddress: 'Bucandala-Alapan Road, Imus City, Cavite',
      description: 'Imus Heritage Park, formally known as the Shrine of the National Flag, commemorates the Filipino victory in the Battle of Alapan on May 28, 1898. The park contains the Mother of Freedom monument, flag displays, memorials, and a prominent flagpole. It is the principal venue in Imus for National Flag Day observances.',
      category: 'Historical Park / Shrine', latitude: 14.40400, longitude: 120.91529,
      websiteUrl: citySource, visitDuration: '45 minutes to 1.5 hours', bestTimeToVisit: 'Early morning or late afternoon; May 28 for official National Flag Day ceremonies',
      historicalBackground: 'Filipino forces under General Emilio Aguinaldo defeated Spanish troops at Alapan on May 28, 1898. After the victory, the Philippine flag made in Hong Kong by Marcela Agoncillo, Lorenza Agoncillo, and Delfina Herbosa de Natividad was publicly unfurled in triumph. The National Historical Institute declared the site a National Historical Landmark through Resolution No. 5, series of 1993. The developed heritage park now serves as the city’s main national-flag memorial complex.',
      culturalSignificance: 'The shrine explains why Imus is known as the Flag Capital of the Philippines. It links the Battle of Alapan, the return of the revolution, and the national observance that begins on May 28 and continues through Independence Day.',
      yearEstablished: 'National Historical Landmark declared in 1993',
      importantPeople: ['General Emilio Aguinaldo', 'Marcela Agoncillo', 'Lorenza Agoncillo', 'Delfina Herbosa de Natividad', 'Filipino revolutionaries of the Battle of Alapan'],
      importantEvents: ['May 28, 1898 – Filipino forces won the Battle of Alapan.', 'May 28, 1898 – The Philippine flag was unfurled in victory.', 'May 26, 1993 – The site was declared a National Historical Landmark.', 'May 28 each year – Imus hosts National Flag Day commemorations.'],
      interestingFacts: ['May 28 is the beginning of the annual National Flag Days.', 'The park is also called Dambana ng Pambansang Watawat.', 'The site is distinct from the NHCP marker near Alapan I Elementary School.'],
      informationSources: [citySource, 'https://philhistoricsites.nhcp.gov.ph/registry_database/labanan-sa-alapan/', 'https://cityofimus.gov.ph/News/230_2024_May_Pambansang_araw_ng_watawat', 'https://commons.wikimedia.org/wiki/File:Imus_Heritage_Park.jpg'],
      safetyReminders: 'Use designated paths and parking areas. Keep away from road traffic and do not climb monuments or the flagpole.',
      visitorTips: 'Read the monuments as a group and allow time to walk around the park. Contact the tourism office before bringing a school group or arranging a guided visit.',
      publicationStatus: 'published', verifiedBy,
    },
  },
  {
    ...commonOutdoor,
    name: 'Battle of Alapan Historical Marker',
    aliases: ['Labanan sa Alapan Marker', 'Battle of Alapan Marker', 'Alapan Battle Site'],
    imageUrls: ['https://commons.wikimedia.org/wiki/Special:Redirect/file/Labanan%20sa%20Alapan%20NHCP%20Historical%20Marker.jpg'],
    data: {
      ...commonOutdoor,
      shortSummary: 'The NHCP marker identifying the Alapan battle site where Filipino revolutionaries defeated Spanish forces on May 28, 1898.',
      municipality: 'Imus', barangay: 'Alapan I-B', streetAddress: 'Near Alapan I Elementary School, Alapan, Imus City, Cavite',
      description: 'The Battle of Alapan Historical Marker identifies the area associated with the May 28, 1898 revolutionary victory. The NHCP marker records that the victory signaled the renewed strength of the revolution and that the Philippine flag was first waved here after the battle.',
      category: 'Historical Marker / Battle Site', latitude: 14.41569, longitude: 120.91865,
      websiteUrl: 'https://philhistoricsites.nhcp.gov.ph/registry_database/labanan-sa-alapan/', visitDuration: '20 to 40 minutes', bestTimeToVisit: 'Daylight hours on a school day only when access does not disrupt classes',
      historicalBackground: 'After returning from exile in Hong Kong, Emilio Aguinaldo renewed the struggle against Spain. On May 28, 1898, Filipino forces defeated a Spanish column at Alapan. The event became closely associated with the first victorious display of the Philippine flag and the birth of the First Philippine Republic. The current NHCP marker dates to 2014.',
      culturalSignificance: 'The marker preserves the precise local memory of the Battle of Alapan and complements the larger memorial landscape at Imus Heritage Park.',
      yearEstablished: 'NHCP marker dated 2014',
      importantPeople: ['General Emilio Aguinaldo', 'Filipino revolutionaries at Alapan', 'Spanish colonial troops at Alapan'],
      importantEvents: ['May 28, 1898 – Battle of Alapan.', '2014 – Current NHCP historical marker dated.'],
      interestingFacts: ['The marker and Imus Heritage Park are separate pins.', 'The NHCP classifies it as a Level II historical marker.', 'The marker text connects the battle with the rise of the First Philippine Republic.'],
      informationSources: ['https://philhistoricsites.nhcp.gov.ph/registry_database/labanan-sa-alapan/', citySource, 'https://commons.wikimedia.org/wiki/File:Labanan_sa_Alapan_NHCP_Historical_Marker.jpg'],
      photographyRules: 'Photograph from public areas without disrupting school operations, students, traffic, or ceremonies.',
      prohibitedItems: 'Do not enter school-controlled areas without permission, photograph children without consent, climb the marker, or block the road.',
      safetyReminders: 'This location is near a school and road. Follow school security rules, use safe pedestrian areas, and supervise children.',
      visitorTips: 'For an easier public visit and broader interpretation, continue to nearby Imus Heritage Park after viewing the marker.',
      publicationStatus: 'published', verifiedBy,
    },
  },
  {
    ...commonOutdoor,
    name: 'Battle of Imus Monument',
    aliases: ['Shrine of Filipino Revolutionaries', 'Dambana ng mga Pilipinong Rebolusyonaryo', 'Labanan sa Imus Monument'],
    imageUrls: ['https://www.cityofimus.gov.ph/Media/Battle-of-Imus.jpg'],
    data: {
      ...commonOutdoor,
      shortSummary: 'A monument beside the old Imus cuartel commemorating the decisive Filipino victory in the Battle of Imus in September 1896.',
      municipality: 'Imus', barangay: 'Poblacion I-A', streetAddress: 'General E. Topacio Street, Poblacion I-A, Imus City, Cavite',
      description: 'The Battle of Imus Monument, officially called the Shrine of Filipino Revolutionaries, stands near the old Imus cuartel and Bridge of Isabel II. Its sculptures and markers commemorate the Filipino forces who defeated Spanish troops during the Battle of Imus, an early and decisive victory of the Philippine Revolution.',
      category: 'Monument / Memorial', latitude: 14.42998, longitude: 120.94029,
      websiteUrl: citySource, visitDuration: '30 to 45 minutes', bestTimeToVisit: 'Morning or late afternoon; September commemorations may include ceremonies',
      historicalBackground: 'Revolutionary forces led by Emilio Aguinaldo and local commanders fought Spanish troops around the Imus River, bridge, and cuartel in early September 1896. The victory strengthened the revolution in Cavite after earlier setbacks elsewhere. NHCP records identify the Cuartel of Imus as the battle site and a historical marker was installed in 2006.',
      culturalSignificance: 'The monument honors ordinary revolutionaries and local leaders whose victory helped establish Cavite as a center of the Philippine Revolution.',
      yearEstablished: 'Battle in 1896; NHCP marker dated 2006',
      importantPeople: ['General Emilio Aguinaldo', 'Colonel Jose S. Tagle', 'General Licerio Topacio', 'Filipino revolutionaries of Imus'],
      importantEvents: ['September 1–3, 1896 – Battle of Imus.', 'September 3, 2006 – NHCP marker dated for the battle site.'],
      interestingFacts: ['Its official English name is Shrine of Filipino Revolutionaries.', 'It forms a compact heritage cluster with Bridge of Isabel II and the Imus Historical Museum.', 'The monument depicts Emilio Aguinaldo and revolutionary fighters.'],
      informationSources: [citySource, 'https://philhistoricsites.nhcp.gov.ph/registry_database/labanan-sa-imus/', 'https://commons.wikimedia.org/wiki/Category:Battle_of_Imus_Monument'],
      safetyReminders: 'Stay on pedestrian areas and remain alert near the bridge and surrounding streets. Do not climb the sculptures.',
      visitorTips: 'Visit the monument, bridge, and museum together to understand the battlefield landscape.',
      publicationStatus: 'published', verifiedBy,
    },
  },
  {
    ...commonOutdoor,
    name: 'Bridge of Isabel II',
    aliases: ['Isabel Bridge', 'Tulay ni Isabel II', 'Isabela Bridge', 'Julian Bridge'],
    imageUrls: ['https://www.cityofimus.gov.ph/Media/isabelabridge.jpg'],
    data: {
      ...commonOutdoor,
      shortSummary: 'A surviving Spanish colonial stone-arch bridge completed in 1857 and closely associated with the Battle of Imus.',
      municipality: 'Imus', barangay: 'Palico I', streetAddress: 'General E. Topacio Street over the Imus River, Palico, Imus City, Cavite',
      description: 'Bridge of Isabel II is a historic two-span stone-arch bridge over the Imus River. Built shortly before 1857 for the Hacienda de Imus, it later became part of the battlefield landscape of the Battle of Imus. Historical markers and nearby monuments explain its engineering and revolutionary importance.',
      category: 'Heritage Bridge', latitude: 14.43023, longitude: 120.94023,
      websiteUrl: citySource, visitDuration: '20 to 40 minutes', bestTimeToVisit: 'Daylight hours during clear weather',
      historicalBackground: 'Recollect lay brother Matias Carbonell supervised construction of the bridge shortly before 1857 while overseeing the Hacienda de Imus. Governor-General Ramon Montero awarded him a silver medal for the work. The bridge later figured in the Battle of Imus in September 1896, when revolutionary forces fought Spanish troops around the river crossing and cuartel.',
      culturalSignificance: 'The bridge is both a rare surviving example of nineteenth-century stone bridge engineering and a physical witness to one of the revolution’s key early victories.',
      yearEstablished: 'Completed in 1857',
      importantPeople: ['Brother Matias Carbonell, OAR', 'Governor-General Ramon Montero', 'General Emilio Aguinaldo', 'Colonel Jose S. Tagle'],
      importantEvents: ['Before 1857 – Bridge constructed for Hacienda de Imus.', '1857 – Bridge completed.', 'September 1896 – Bridge became part of the Battle of Imus battlefield.'],
      interestingFacts: ['The bridge uses two stone arches.', 'Its builder received a silver medal from the governor-general.', 'The Battle of Imus Monument stands beside it.'],
      informationSources: [citySource, 'https://philhistoricsites.nhcp.gov.ph/registry_database/tulay-ni-isabel-ii/', 'https://commons.wikimedia.org/wiki/Category:Bridge_of_Isabel_II'],
      safetyReminders: 'Watch for traffic and slippery or uneven surfaces. Do not climb parapets or approach the river edge, especially during rain or flooding.',
      visitorTips: 'View the arches from a safe public vantage point and combine the stop with the Battle of Imus Monument and Historical Museum.',
      publicationStatus: 'published', verifiedBy,
    },
  },
  {
    name: 'Imus Historical Museum',
    aliases: ['Museong Pangkasaysayan ng Imus', 'Imus Museum', 'Arsenal ng Imus', 'Imus Arsenal'],
    imageUrls: ['https://www.cityofimus.gov.ph/Media/image_museumimus1.jpg'],
    data: {
      shortSummary: 'A local history museum built on the site of Jose Ignacio Paua’s revolutionary arsenal and workshop.',
      municipality: 'Imus', barangay: 'Poblacion I-A', streetAddress: 'General E. Topacio Street, Poblacion I-A, Imus City, Cavite',
      description: 'Imus Historical Museum presents episodes from the city’s history through life-size tableaus, murals, reliefs, captions, and sensor-activated displays. The fortress-like museum occupies the site associated with the Arsenal ng Imus, where Jose Ignacio Paua and fellow workers made and repaired weapons for Filipino revolutionaries.',
      category: 'Museum', latitude: 14.42967, longitude: 120.94013,
      openingDays: 'Contact the City Tourism and Heritage Office before visiting; schedules may change', openingTime: '', closingTime: '', isAlwaysOpen: false,
      entranceFee: '', isFreeEntrance: true, contactNumber: tourismContact,
      websiteUrl: citySource, visitDuration: '45 minutes to 1.5 hours', bestTimeToVisit: 'Weekday morning after confirming museum availability', operatingStatus: 'open',
      historicalBackground: 'In 1896, Chinese-Filipino blacksmith Jose Ignacio Paua established an arsenal in Imus under orders from Emilio Aguinaldo. Paua and other Chinese and revolutionary workers manufactured and repaired rifles and lantaka for the struggle against Spain. The later museum commemorates this workshop and interprets the wider history of Imus and the Cavite Revolution.',
      culturalSignificance: 'The museum preserves the story of revolutionary logistics, craftsmanship, migration, and local participation—not only battlefield leadership. Its displays make Imus history accessible to students and families.',
      yearEstablished: 'Arsenal established in 1896; later developed as a historical museum',
      importantPeople: ['General Jose Ignacio Paua', 'General Emilio Aguinaldo', 'Chinese-Filipino artisans', 'Filipino revolutionaries of Imus'],
      importantEvents: ['1896 – Jose Ignacio Paua established the revolutionary arsenal.', 'Revolutionary period – Weapons were manufactured and repaired at the site.', 'Modern period – Site developed as Imus Historical Museum.'],
      interestingFacts: ['The museum uses sensor-activated life-size tableaus.', 'Jose Ignacio Paua was a blacksmith who later became a revolutionary general.', 'The museum is only a short walk from Bridge of Isabel II.'],
      informationSources: [citySource, 'https://philhistoricsites.nhcp.gov.ph/registry_database/arsenal-ng-imus/', 'https://commons.wikimedia.org/wiki/Category:Imus_Historical_Museum'],
      dressCode: 'Wear respectful casual clothing and comfortable footwear.',
      photographyRules: 'Ask museum staff before taking photographs, using flash, filming, or photographing artifacts and displays.',
      prohibitedItems: 'Do not touch displays, bring food or drinks into exhibit areas, use flash without permission, or create excessive noise.',
      petPolicy: 'Pets are generally unsuitable inside museum galleries except trained service animals, subject to museum policy.',
      safetyReminders: 'Follow staff instructions and exhibit barriers. Children should remain supervised.', emergencyContact,
      visitorTips: 'Call the tourism office before traveling to confirm opening hours and group-tour arrangements. Pair the museum with the adjacent bridge and battle monument.',
      publicationStatus: 'published', verifiedBy,
    },
  },
  {
    ...commonOutdoor,
    name: 'Imus City Plaza',
    aliases: ['Imus Plaza', 'Plaza Santiago', 'Imus Town Plaza'],
    imageUrls: ['https://www.cityofimus.gov.ph/Media/Imus%20Plaza.jpg'],
    data: {
      ...commonOutdoor,
      shortSummary: 'The historic civic square of Imus, surrounded by the cathedral and monuments to the city’s people and revolutionary history.',
      municipality: 'Imus', barangay: 'Poblacion III-A', streetAddress: 'Castañeda Street corner Maestro G. Tirona Street, Poblacion, Imus City, Cavite',
      description: 'Imus City Plaza is the traditional civic heart of the old town. The landscaped square contains historical markers and monuments, including memorials connected with Imus heroes and major battles. It stands opposite Imus Cathedral and remains a setting for public gatherings and cultural activities.',
      category: 'Public Plaza / Park', latitude: 14.42901, longitude: 120.93658,
      websiteUrl: citySource, visitDuration: '30 minutes to 1 hour', bestTimeToVisit: 'Early morning or late afternoon; evenings may be lively during local events',
      historicalBackground: 'The plaza developed at the center of the settlement that became the municipality of Imus in 1795. A city historical marker recounts the town’s occupation during the revolution, later changes of government, the Japanese occupation, and liberation. The plaza was beautified with Philippine Tourism Authority assistance in 1990 and underwent major rehabilitation in 2009.',
      culturalSignificance: 'The plaza gathers Imus’s civic, religious, and historical identity in one walkable place. Its markers and monuments turn an everyday public space into an outdoor local-history gallery.',
      yearEstablished: 'Historic town center; beautified in 1990 and rehabilitated in 2009',
      importantPeople: ['General Licerio Topacio', 'The Thirteen Martyrs of Imus', 'Prominent revolutionary generals of Imus', 'Residents of Imus'],
      importantEvents: ['1795 – Imus organized as a municipality.', 'September 1896 – Revolutionaries occupied Imus.', '1990 – Plaza refined and beautified.', '2009 – Plaza underwent total rehabilitation.'],
      interestingFacts: ['The plaza contains several separate monuments and historical markers.', 'It sits directly across from Imus Cathedral.', 'The tomb and monument of General Licerio Topacio form part of the plaza’s memorial landscape.'],
      informationSources: [citySource, 'https://philhistoricsites.nhcp.gov.ph/registry_database/imus/', 'https://commons.wikimedia.org/wiki/Category:Imus_Plaza'],
      safetyReminders: 'Use pedestrian crossings around the plaza and supervise children near streets and monuments.',
      visitorTips: 'Walk around the plaza slowly to find its different monuments, then cross safely to Imus Cathedral.',
      publicationStatus: 'published', verifiedBy,
    },
  },
  {
    name: 'Imus Cathedral',
    aliases: ['Diocesan Shrine and Parish of Our Lady of the Pillar', 'Our Lady of the Pillar Cathedral', 'Cathedral of Our Lady of the Pillar'],
    imageUrls: ['https://www.cityofimus.gov.ph/Media/Imus%20Cathedral.JPG'],
    data: {
      shortSummary: 'The cathedral of the Diocese of Imus, known for its historic brick architecture and devotion to Nuestra Señora del Pilar.',
      municipality: 'Imus', barangay: 'Poblacion III-A', streetAddress: 'General J. Castañeda Street, Poblacion, Imus City, Cavite 4103',
      description: 'The Diocesan Shrine and Parish of Our Lady of the Pillar, commonly called Imus Cathedral, is the seat of the Diocese of Imus. Its brick arches, walls, Latin inscriptions, heritage bells, and long religious traditions make it one of the city’s defining cultural landmarks.',
      category: 'Church / Religious Site', latitude: 14.42979, longitude: 120.93610,
      openingDays: 'Monday to Sunday; visitor access may be limited during Masses, rites, and parish activities', openingTime: '', closingTime: '', isAlwaysOpen: false,
      entranceFee: '', isFreeEntrance: true, contactNumber: tourismContact,
      websiteUrl: 'https://imusdiocese.net/', visitDuration: '45 minutes to 1 hour', bestTimeToVisit: 'Weekday mornings or outside scheduled liturgies', operatingStatus: 'open',
      historicalBackground: 'The Augustinian Recollects established the parish tradition that became associated with Nuestra Señora del Pilar, whose image was brought to Cavite in 1694. After earlier church sites were damaged or relocated, the parish settled near the present plaza. The Diocese of Imus was canonically erected in 1961, making the church its cathedral. Nuestra Señora del Pilar was canonically crowned on December 3, 2012.',
      culturalSignificance: 'The cathedral is the religious center of the Diocese of Imus and a major expression of the city’s identity. Its annual October feast, processions, music, heritage bells, architecture, and Marian devotion connect generations of Imuseños.',
      yearEstablished: 'Parish roots in the Spanish colonial period; cathedral since 1961',
      importantPeople: ['Nuestra Señora del Pilar', 'Augustinian Recollect missionaries', 'Bishops of the Diocese of Imus', 'Catholic community of Cavite'],
      importantEvents: ['May 28, 1694 – Recollects brought the image of Nuestra Señora del Pilar to Cavite.', 'November 25, 1961 – Diocese of Imus canonically erected.', 'December 3, 2012 – Nuestra Señora del Pilar canonically crowned.', 'October 12 each year – Patronal feast celebrated.'],
      interestingFacts: ['The church is built with prominent red brick arches and walls.', 'It is the episcopal seat for the Catholic diocese covering Cavite.', 'Its complex includes heritage bells, a Hall of Saints, and Saint Ezekiel Moreno Garden.'],
      informationSources: [citySource, 'https://cityofimus.gov.ph/News/508_2025_Dec_PhilippineMarianPilgrimageTour', 'https://commons.wikimedia.org/wiki/Category:Imus_Cathedral'],
      dressCode: 'Wear modest clothing appropriate for an active place of worship. Keep phones silent and remove hats when appropriate.',
      photographyRules: 'Personal photography is generally appropriate outside services. Ask parish permission before using flash, tripods, drones, or photographing ceremonies.',
      prohibitedItems: 'Do not bring food or drinks into worship areas, touch sacred objects, create excessive noise, or disrupt Mass and parish activities.',
      petPolicy: 'Pets should remain outside worship areas unless they are trained service animals or parish permission is given.',
      safetyReminders: 'Use pedestrian crossings around the plaza and take care on steps or wet floors.', emergencyContact,
      visitorTips: 'Check the cathedral’s current liturgical schedule. Visit respectfully and combine the stop with the adjacent city plaza.',
      publicationStatus: 'published', verifiedBy,
    },
  },
  {
    ...commonOutdoor,
    name: 'Battle of Pasong Santol Historical Marker',
    aliases: ['Labanan sa Pasong Santol', 'Pasong Santol Marker', 'Battle of Pasong Santol Memorial'],
    imageUrls: ['https://www.cityofimus.gov.ph/Media/image_pasongsantol1.jpg'],
    data: {
      ...commonOutdoor,
      shortSummary: 'An NHCP marker commemorating the 1897 battle in which General Crispulo Aguinaldo and other revolutionaries fought Spanish forces.',
      municipality: 'Imus', barangay: 'Anabu II-E', streetAddress: 'Santiago Subdivision, Barangay Anabu II-E, Imus City, Cavite',
      description: 'The Battle of Pasong Santol Historical Marker commemorates the fierce fighting of March 24, 1897. The marker records that General Crispulo Aguinaldo was mortally wounded while commanding Filipino forces against Spanish troops at this site.',
      category: 'Historical Marker / Battle Site', latitude: 14.36535, longitude: 120.94020,
      websiteUrl: 'https://philhistoricsites.nhcp.gov.ph/registry_database/labanan-sa-pasong-santol/', visitDuration: '20 to 40 minutes', bestTimeToVisit: 'Daylight hours during clear weather',
      historicalBackground: 'During the revolutionary struggle in Cavite, Filipino forces defended Pasong Santol against a Spanish offensive on March 24, 1897. General Crispulo Aguinaldo, elder brother of Emilio Aguinaldo, was left in temporary command while Emilio traveled to Tejeros to take his oath under the new revolutionary government. Crispulo was mortally wounded in the battle. The historical marker was installed in 1971.',
      culturalSignificance: 'The site remembers the cost of the revolution and the sacrifices of commanders and ordinary fighters during a difficult Spanish counteroffensive.',
      yearEstablished: 'Battle in 1897; historical marker installed in 1971',
      importantPeople: ['General Crispulo Aguinaldo', 'General Emilio Aguinaldo', 'General Flaviano Yengko', 'Marcela Marcelo', 'Filipino defenders of Pasong Santol'],
      importantEvents: ['March 22, 1897 – Tejeros Convention established a new revolutionary government.', 'March 24, 1897 – Battle of Pasong Santol and mortal wounding of Crispulo Aguinaldo.', 'March 24, 1971 – Historical marker dated.'],
      interestingFacts: ['Crispulo Aguinaldo was Emilio Aguinaldo’s elder brother.', 'The site is recognized by the NHCP as a Level II historical marker.', 'The marker is within the Anabu II area, south of the old Imus town center.'],
      informationSources: ['https://philhistoricsites.nhcp.gov.ph/registry_database/labanan-sa-pasong-santol/', citySource],
      safetyReminders: 'The marker is in a neighborhood setting. Use safe pedestrian areas, respect residents, and avoid blocking roads or driveways.',
      visitorTips: 'Use the exact map pin because Pasong Santol is also the name of a wider locality. Visit quietly and read the NHCP marker at the site.',
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
      const response = await fetch(url, { redirect: 'follow', headers: { 'User-Agent': 'CaviteExplorer/1.0 (landmark data import)' } });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const contentType = response.headers.get('content-type') || '';
      if (!contentType.startsWith('image/')) throw new Error(`Unexpected content type ${contentType}`);
      const filename = `${randomUUID()}${extensionFor(response.url || url, contentType)}`;
      await writeFile(join(uploadDirectory, filename), Buffer.from(await response.arrayBuffer()));
      paths.push(`/uploads/landmarks/${filename}`);
    } catch (error) {
      console.warn(`Image skipped (${url}): ${error.message}`);
    }
  }
  return paths;
}

async function upsertRecord(record) {
  const names = [record.name, ...(record.aliases || [])];
  const matches = await prisma.landmark.findMany({
    where: { municipality: { equals: 'Imus', mode: 'insensitive' }, name: { in: names } },
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
    where: { municipality: 'Imus', name: { in: officialNames }, publicationStatus: 'published' },
    select: { name: true, barangay: true, category: true, images: true },
    orderBy: { name: 'asc' },
  });
  console.log(`\nPublished Imus heritage and tourism sites: ${completed.length}/${officialNames.length}`);
  for (const place of completed) console.log(`- ${place.name} | ${place.barangay} | ${place.category} | ${place.images.length} image(s)`);
  if (completed.length !== officialNames.length || completed.some((place) => place.images.length === 0)) process.exitCode = 1;
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}).finally(async () => {
  await prisma.$disconnect();
});
