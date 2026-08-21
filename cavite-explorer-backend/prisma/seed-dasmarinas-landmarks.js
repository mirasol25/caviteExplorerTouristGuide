require('dotenv').config();

const { PrismaClient } = require('@prisma/client');
const { randomUUID } = require('crypto');
const { mkdir, writeFile } = require('fs/promises');
const { extname, join } = require('path');

const prisma = new PrismaClient();
const uploadDirectory = join(process.cwd(), 'uploads', 'landmarks');
const citySource = 'https://cityofdasmarinas.gov.ph/';
const provincialSource = 'https://tourism.cavite.gov.ph/cavite-tourism-passport/';
const tourismContact = '(046) 481-4600 local 636/637';
const emergencyContact = 'Emergency: 911\nDasmariñas Ambulance Center: (046) 686-3339 / (046) 851-0955\nBureau of Fire Protection: (046) 416-0875\nDasmariñas PNP: (046) 416-2924';
const verifiedBy = 'josephmirasol25@gmail.com';

const commonOutdoor = {
  entranceFee: '', isFreeEntrance: true, contactNumber: tourismContact, operatingStatus: 'open',
  dressCode: 'Wear comfortable, weather-appropriate clothing and walking shoes.',
  photographyRules: 'Personal photography is generally appropriate. Ask permission before using drones, tripods, or professional equipment, and do not obstruct other visitors.',
  prohibitedItems: 'Do not litter, vandalize facilities, enter restricted areas, consume alcohol, or create excessive noise.',
  petPolicy: 'No current official pet policy is published. Keep pets leashed and supervised and clean up after them.',
  emergencyContact,
};

const records = [
  {
    name: 'Immaculate Conception Parish Church of Dasmariñas',
    aliases: ['Dasmariñas Church', 'Simbahan ng Dasmariñas', 'Parish Church of Immaculate Conception of Dasmariñas', 'Immaculate Conception Parish Church'],
    imageUrls: [
      'https://commons.wikimedia.org/wiki/Special:Redirect/file/Dasmari%C3%B1asChurchjf9400%2011.JPG',
    ],
    data: {
      shortSummary: 'The historic mother parish of Dasmariñas and site of battles and civilian suffering during the Philippine Revolution and World War II.',
      municipality: 'Dasmariñas', barangay: 'Zone IV', streetAddress: 'Don Placido Campos Avenue corner Camerino Avenue, Zone IV, Dasmariñas City, Cavite 4114',
      description: 'The Immaculate Conception Parish Church, commonly called Dasmariñas Church, is the city’s oldest Catholic parish church. Its stone church and convent served as a Spanish civil-government center and became the scene of the bloody Battle of Perez-Dasmariñas in 1897. The complex also remembers civilians imprisoned and killed during the Japanese occupation.',
      category: 'Church / Religious Site', latitude: 14.32704, longitude: 120.93605,
      openingDays: 'Monday to Sunday; visitor access may be limited during Masses, rites, and parish activities', openingTime: '', closingTime: '', isAlwaysOpen: false,
      entranceFee: '', isFreeEntrance: true, contactNumber: tourismContact,
      websiteUrl: 'https://philhistoricsites.nhcp.gov.ph/registry_database/simbahan-ng-dasmarinas/', visitDuration: '45 minutes to 1 hour', bestTimeToVisit: 'Weekday mornings or outside scheduled liturgies', operatingStatus: 'open',
      historicalBackground: 'The settlement was formerly a chapel associated with Imus. Augustinian Recollect priests established the parish of Camarin de Piedra under the patronage of the Immaculate Conception in 1867, with Father Valentin Diaz as its first parish priest. The stone church and convent also served the Spanish civil government. On February 25, 1897, Spanish troops defeated revolutionaries led by Captain Placido Campos and his secretary Francisco Barzaga in a bloody battle around the complex. On December 17, 1944, Japanese forces confined residents here and killed seventeen people who were buried together. The National Historical Institute unveiled a marker in 1986.',
      culturalSignificance: 'The church joins the city’s Catholic identity with memories of revolution, occupation, sacrifice, and survival. Its NHCP marker makes it Dasmariñas’s principal nationally documented heritage structure.',
      yearEstablished: 'Parish established in 1867; NHCP marker unveiled in 1986',
      importantPeople: ['Father Valentin Diaz', 'Captain Placido Campos', 'Francisco Barzaga', 'Augustinian Recollect missionaries', 'Victims of December 17, 1944'],
      importantEvents: ['1867 – Parish of Camarin de Piedra established.', 'February 25, 1897 – Battle of Perez-Dasmariñas fought at the church and convent.', 'December 17, 1944 – Residents were confined and seventeen people were killed.', '1986 – National Historical Institute marker unveiled.', 'December 7–8, 2002 – Patroness episcopally crowned and church dedicated.'],
      interestingFacts: ['The convent once housed the Spanish civil government.', 'The NHCP classifies the marker as Level II.', 'The church celebrated its 150th jubilee in 2017.'],
      informationSources: ['https://philhistoricsites.nhcp.gov.ph/registry_database/simbahan-ng-dasmarinas/', provincialSource, 'https://commons.wikimedia.org/wiki/Category:Dasmari%C3%B1as_Church'],
      dressCode: 'Wear modest clothing appropriate for an active place of worship. Keep phones silent and remove hats when appropriate.',
      photographyRules: 'Personal photography is generally appropriate outside services. Ask parish permission before using flash, tripods, drones, or photographing ceremonies.',
      prohibitedItems: 'Do not bring food or drinks into worship areas, touch sacred objects or markers, create excessive noise, or disrupt Mass and parish activities.',
      petPolicy: 'Pets should remain outside worship areas unless they are trained service animals or parish permission is given.',
      safetyReminders: 'Use pedestrian crossings around the town center and take care on steps and wet floors.', emergencyContact,
      visitorTips: 'Read the NHCP marker and visit respectfully. Contact the parish or tourism office before bringing a school group.',
      publicationStatus: 'published', verifiedBy,
    },
  },
  {
    name: 'Museo De La Salle',
    aliases: ['Museo de La Salle', 'Museo De La Salle DLSU-D', 'De La Salle Museum Dasmariñas'],
    imageUrls: [
      'https://www.dlsud.edu.ph/facilities/assets/img/museo/1.png',
      'https://www.dlsud.edu.ph/facilities/assets/img/museo/2.png',
      'https://www.dlsud.edu.ph/facilities/assets/img/museo/3.png',
    ],
    data: {
      shortSummary: 'A museum-scale bahay na bato interpreting nineteenth-century Philippine ilustrado life through period rooms, antiques, art, and guided tours.',
      municipality: 'Dasmariñas', barangay: 'Fatima I', streetAddress: 'Lake Avenue, East Campus, De La Salle University–Dasmariñas, Barangay Fatima I, Dasmariñas City, Cavite 4115',
      description: 'Museo De La Salle is a cultural and historical institution within De La Salle University–Dasmariñas. Designed as an enlarged nineteenth-century bahay na bato, it presents period rooms filled with woodcarving, hand-painted decoration, furniture, religious objects, fine and applied art, and family heirlooms that interpret the material culture of Philippine ilustrado households.',
      category: 'Museum', latitude: 14.32100, longitude: 120.96104,
      openingDays: 'Monday to Friday; advance booking is recommended', openingTime: '09:00', closingTime: '17:00', isAlwaysOpen: false,
      entranceFee: 'Contact the museum for current tour and admission charges', isFreeEntrance: false, contactNumber: '(046) 481-1940 / (046) 481-1900 to 1930 local 3151',
      websiteUrl: 'https://www.dlsud.edu.ph/museodelasalle/about.htm', visitDuration: '1 to 2 hours', bestTimeToVisit: 'Weekday morning with a confirmed guided-tour reservation', operatingStatus: 'open',
      historicalBackground: 'Brother Andrew Gonzalez, FSC, conceived the museum after visiting the restored Joven Panlilio House in Bacolor in 1988. The 1991 Mount Pinatubo eruption forced the Panlilio family to dismantle their ancestral house, renewing plans to preserve heirlooms and interpret nineteenth-century domestic culture at De La Salle University–Dasmariñas. Construction began in 1996 under interior designer and project manager Jose Ma. Ricardo “Joey” Panlilio, with contributions from consultants, donors, and collectors.',
      culturalSignificance: 'The museum preserves and interprets Philippine art, architecture, craftsmanship, social history, and domestic life. It is both a teaching collection and a major cultural destination in Cavite.',
      yearEstablished: 'Conceived in 1988; construction began in 1996',
      importantPeople: ['Brother Andrew Gonzalez, FSC', 'Jose Ma. Ricardo “Joey” Panlilio', 'Dr. Jaime Laya', 'Dr. Eleuterio Pascual', 'The Panlilio family'],
      importantEvents: ['1988 – Brother Andrew visited the Joven Panlilio House and formed the museum vision.', '1991 – Mount Pinatubo eruption led to dismantling of the Panlilio ancestral home.', '1996 – Construction of Museo De La Salle began.', 'Modern period – Museum opened its collections to the public through guided tours.'],
      interestingFacts: ['The building is approximately three times the scale of a traditional bahay na bato.', 'Its rooms are arranged to evoke nineteenth-century ilustrado domestic life.', 'The museum hosts lectures, exhibitions, workshops, and cultural events in addition to tours.'],
      informationSources: ['https://www.dlsud.edu.ph/museodelasalle/about.htm', 'https://www.dlsud.edu.ph/facilities/museo.htm', provincialSource, 'https://www.pna.gov.ph/articles/1044982'],
      dressCode: 'Wear respectful casual clothing suitable for a university campus and museum galleries.',
      photographyRules: 'Photography, filming, professional shoots, flash, and equipment are subject to museum permission and reservation policies.',
      prohibitedItems: 'Do not touch artifacts, bring food or drinks into galleries, use flash without permission, or enter staff-only and restricted areas.',
      petPolicy: 'Pets are generally unsuitable inside university museum galleries except trained service animals, subject to campus policy.',
      safetyReminders: 'Follow campus security, museum staff instructions, exhibit barriers, and emergency procedures. Children should remain supervised.', emergencyContact,
      visitorTips: 'Book a guided tour before traveling and bring a valid ID for campus entry. Confirm current fees, schedules, and photography rules directly with the museum.',
      publicationStatus: 'published', verifiedBy,
    },
  },
  {
    ...commonOutdoor,
    name: 'Promenade Des Dasmariñas',
    aliases: ['Promenade de Dasmariñas', 'Promenade Dasmariñas', 'Dasmariñas Promenade', 'Promenade River Park'],
    imageUrls: [
      'https://files01.pna.gov.ph/source/2022/02/02/inside-the-park.jpg',
    ],
    data: {
      ...commonOutdoor,
      shortSummary: 'A landscaped riverside urban garden with walkways, bicycle areas, gazebos, fountains, lighting, and public recreation spaces.',
      municipality: 'Dasmariñas', barangay: 'Burol Main', streetAddress: 'Riverside along Governor D. Mangubat Avenue and Congressional Road, Barangay Burol Main, Dasmariñas City, Cavite',
      description: 'Promenade Des Dasmariñas is a public riverside urban garden created from previously idle land along a tributary of the Imus River. Its landscaped grounds, walkways, bicycle facilities, gazebos, fountains, cascading water feature, lighting, and decorative installations provide a major open-air recreation space for walking, exercise, and family visits.',
      category: 'Park / Recreation', latitude: 14.32565, longitude: 120.95616,
      openingDays: 'Monday to Sunday; confirm current access during maintenance, events, or severe weather', openingTime: '05:00', closingTime: '00:00', isAlwaysOpen: false,
      websiteUrl: citySource, visitDuration: '1 to 2 hours', bestTimeToVisit: 'Early morning for exercise or late afternoon to evening for cooler weather and decorative lighting',
      historicalBackground: 'The city transformed more than two hectares of riverside land into an urban garden as part of river rehabilitation and beautification. Promenade Des Dasmariñas publicly opened on March 26, 2019. Later projects added or improved pedestrian and bicycle facilities. The park’s name revives the idea of a public promenade—a place for walking, meeting, exercising, and being seen.',
      culturalSignificance: 'The promenade represents Dasmariñas’s investment in public space, river rehabilitation, active mobility, and community recreation. It is also used as a setting connected with city celebrations such as the Paruparo Festival.',
      yearEstablished: 'Opened March 26, 2019',
      importantPeople: ['Residents of Dasmariñas', 'City Government of Dasmariñas', 'City Tourism and Information Office'],
      importantEvents: ['March 26, 2019 – Promenade opened to the public.', '2021 onward – Pedestrian and bicycle facilities received further development.', 'November celebrations – Areas around the promenade form part of Paruparo Festival activity.'],
      interestingFacts: ['The park covers more than two hectares along the river corridor.', 'Its original published hours were 5:00 AM to midnight.', 'The city promotes Clean As You Go behavior because trash bins were intentionally limited at opening.'],
      informationSources: [citySource, provincialSource, 'https://www.pna.gov.ph/articles/1065842', 'https://cityofdasmarinas.gov.ph/paruparo/', 'https://www.openstreetmap.org/relation/8780589'],
      photographyRules: 'Personal photography is generally appropriate. Do not block paths, photograph private activities intrusively, or use drones and professional equipment without city permission.',
      prohibitedItems: 'Do not bathe in fountains or waterways, litter, damage landscaping, climb installations, enter the river, or obstruct pedestrian and bicycle lanes.',
      safetyReminders: 'Keep children away from the river, fountains, and bicycle traffic. Avoid low areas during heavy rain, flooding, or thunderstorms.',
      visitorTips: 'Bring drinking water and practice Clean As You Go. The park is long, so use the exact pin and choose the nearest entrance for your planned activity.',
      publicationStatus: 'published', verifiedBy,
    },
  },
  {
    ...commonOutdoor,
    name: 'DC Park (Kadiwa Park)',
    aliases: ['DC Park', 'Kadiwa Park', 'Dasmariñas City Park', 'Kadiwa Dinosaur Park'],
    imageUrls: [
      'https://files01.pna.gov.ph/source/2021/01/09/kadiwa-park.jpg',
      'https://philippinescities.com/wp-content/uploads/2015/09/dasmarinas-kadiwa-park.jpg',
    ],
    data: {
      ...commonOutdoor,
      shortSummary: 'A landscaped public park known for shaded paths, waterfalls, illuminated displays, and playful animal and dinosaur sculptures.',
      municipality: 'Dasmariñas', barangay: 'Burol I', streetAddress: 'Congressional Road near Governor D. Mangubat Avenue, Barangay Burol I, Dasmariñas City, Cavite',
      description: 'DC Park, widely known as Kadiwa Park or Dasmariñas City Park, is a landscaped green space along Congressional Road. It is known locally for shaded paths, seating, water features, seasonal lighting, and artificial animals, birds, and dinosaur figures that make the area popular with families and walkers.',
      category: 'Park / Recreation', latitude: 14.32880, longitude: 120.95745,
      openingDays: 'Monday to Sunday; access and individual features may change during rehabilitation, events, or severe weather', openingTime: '', closingTime: '', isAlwaysOpen: false,
      websiteUrl: citySource, visitDuration: '45 minutes to 1.5 hours', bestTimeToVisit: 'Early morning or late afternoon to evening; avoid rain and peak road traffic',
      historicalBackground: 'Kadiwa Park developed as a public green and recreational space serving the Dasmariñas Bagong Bayan area. The park’s steep landscaped banks, paths, benches, water features, and animal installations made it a recognizable local destination. City maintenance and beautification projects have periodically repaired paths and added decorative lighting and artificial trees.',
      culturalSignificance: 'The park is a familiar community landmark within Dasmariñas Bagong Bayan and provides accessible outdoor leisure in a densely populated urban area.',
      yearEstablished: 'Community park developed before the 2010s; periodically rehabilitated',
      importantPeople: ['Residents of Dasmariñas Bagong Bayan', 'City Government of Dasmariñas', 'Public Safety and maintenance personnel'],
      importantEvents: ['Development as a public landscaped park along Congressional Road.', '2021 – Path rehabilitation and beautification work documented by the Philippine News Agency.', 'Annual holiday periods – Park commonly receives seasonal decorative lighting.'],
      interestingFacts: ['The park is also called DC Park and Dasmariñas City Park.', 'Animal and dinosaur sculptures are among its best-known features.', 'It is adjacent to—but geographically separate from—the much larger Promenade Des Dasmariñas.'],
      informationSources: [citySource, 'https://www.pna.gov.ph/photos/46693', 'https://www.pna.gov.ph/photos/51744', 'https://www.openstreetmap.org/relation/9467537'],
      safetyReminders: 'Supervise children around slopes, steps, roads, water features, and sculptures. Some paths may be uneven or temporarily closed for maintenance.',
      visitorTips: 'Use the DC Park pin rather than the Promenade pin. Confirm current conditions because individual displays and sections can change after rehabilitation.',
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
    where: {
      municipality: { in: ['Dasmariñas', 'Dasmarinas'], mode: 'insensitive' },
      name: { in: names },
    },
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
    where: { municipality: 'Dasmariñas', name: { in: officialNames }, publicationStatus: 'published' },
    select: { name: true, barangay: true, category: true, images: true },
    orderBy: { name: 'asc' },
  });
  console.log(`\nPublished Dasmariñas heritage and tourism sites: ${completed.length}/${officialNames.length}`);
  for (const place of completed) console.log(`- ${place.name} | ${place.barangay} | ${place.category} | ${place.images.length} image(s)`);
  if (completed.length !== officialNames.length || completed.some((place) => place.images.length === 0)) process.exitCode = 1;
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}).finally(async () => {
  await prisma.$disconnect();
});
