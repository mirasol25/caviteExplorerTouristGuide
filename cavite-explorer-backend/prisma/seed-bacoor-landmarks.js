require('dotenv').config();

const { PrismaClient } = require('@prisma/client');
const { randomUUID } = require('crypto');
const { mkdir, writeFile } = require('fs/promises');
const { extname, join } = require('path');

const prisma = new PrismaClient();
const uploadDirectory = join(process.cwd(), 'uploads', 'landmarks');
const tourismContact = '(046) 481-4115 / (046) 481-4100 local 208';
const emergencyContact = 'Bacoor DRRMO: (046) 417-0727\nBacoor City Police: (046) 417-6366\nBacoor Bureau of Fire Protection: (046) 417-6060\nCity Information Office: (046) 481-4120';
const clupSource = 'https://bacoor.gov.ph/wp-content/uploads/2025/10/CLUP_compressed.pdf';
const tourismOfficeSource = 'https://bacoor.gov.ph/city-tourism-development-office/';
const verifiedBy = 'josephmirasol25@gmail.com';

const commonOutdoor = {
  openingDays: 'Monday to Sunday',
  isAlwaysOpen: true,
  entranceFee: '',
  isFreeEntrance: true,
  contactNumber: tourismContact,
  operatingStatus: 'open',
  dressCode: 'Wear comfortable, weather-appropriate clothing and suitable walking shoes.',
  photographyRules: 'Personal photography is generally appropriate. Do not climb on monuments, markers, dams, or other structures, and do not obstruct visitors or ceremonies.',
  prohibitedItems: 'Do not litter, vandalize the site, drink alcohol, create excessive noise, or enter restricted areas.',
  petPolicy: 'No official pet policy is published. Keep pets leashed and supervised, and clean up after them.',
  emergencyContact,
};

const records = [
  {
    name: 'Saint Michael the Archangel Parish Church',
    aliases: ['St. Michael the Archangel Parish Church', 'St. Michael the Archangel Church', 'Simbahan ng Bacoor'],
    imageUrls: [
      'https://bacoor.gov.ph/wp-content/uploads/2024/02/1.-St.-Michael-the-Archangel-Parish-Catholic-Church.jpg',
      'https://bacoor.gov.ph/wp-content/uploads/2024/02/St.-Michael-the-Archangel-Church.jpg',
    ],
    data: {
      shortSummary: 'An Important Cultural Property and historic Bacoor parish associated with Padre Mariano Gomes and the Philippine Revolution.',
      municipality: 'Bacoor', barangay: 'Poblacion', streetAddress: 'General Evangelista Street corner F.L. Pagtakhan Street, Barangay Poblacion, Bacoor City, Cavite',
      description: 'Saint Michael the Archangel Parish Church, commonly called Simbahan ng Bacoor, is one of Bacoor’s most important religious and historical structures. Bacoor became an independent parish in 1752. The present church reflects successive rebuilding after the British invasion, nineteenth-century enlargement under Padre Mariano Gomes and architect Felix Rojas, and restoration after wartime damage. Its belfry was the site of a significant unfurling of the Philippine flag on May 31, 1898.',
      category: 'Church / Religious Site', latitude: 14.45989, longitude: 120.93986,
      openingDays: 'Monday to Sunday; access may be limited during services and parish activities', openingTime: '', closingTime: '', isAlwaysOpen: false,
      entranceFee: '', isFreeEntrance: true, contactNumber: tourismContact,
      websiteUrl: 'https://bacoor.gov.ph/tourism/st-michael-the-archangel-church/', visitDuration: '45 minutes to 1 hour',
      bestTimeToVisit: 'Weekday mornings or outside scheduled Masses', operatingStatus: 'open',
      historicalBackground: 'Bacoor was granted a royal decree establishing its own parish on January 18, 1752. The original church was destroyed during the British invasion in 1762 and rebuilt in stone and wood. Padre Mariano Gomes oversaw major improvements, including a stone convento in 1843 and the enlargement and reorientation of the church with architect Felix Rojas from 1863 to 1870. Revolutionaries raised the Philippine flag on its belfry on May 31, 1898. The church suffered damage during the Philippine-American War in 1899 and was later involved in church ownership disputes resolved in 1906. The National Museum declared it an Important Cultural Property on December 28, 2020.',
      culturalSignificance: 'The church connects Bacoor’s religious history with the secularization movement, GOMBURZA, the Philippine Revolution, and the city’s continuing Catholic traditions. Its surviving bells, historical markers, architecture, and association with Padre Mariano Gomes make it a major heritage landmark.',
      yearEstablished: '1752; enlarged 1863–1870',
      importantPeople: ['Padre Mariano Gomes', 'Bachiller Don Jose Ximenez', 'Architect Felix Rojas', 'Padre Domingo Sevilla Pilapil', 'Don Lorenzo Cuenca'],
      importantEvents: ['January 18, 1752 – Bacoor became an independent parish.', '1762 – The church was destroyed during the British invasion.', '1863–1870 – Padre Mariano Gomes and Felix Rojas enlarged and reoriented the church.', 'May 31, 1898 – Revolutionaries raised the Philippine flag on the belfry.', 'June 13, 1899 – The church was damaged during the Philippine-American War.', 'December 28, 2020 – Declared an Important Cultural Property.', 'March 2, 2022 – NHCP historical marker dated.'],
      interestingFacts: ['The church was reoriented away from Bacoor Bay to reduce seawater entering during high tide.', 'Padre Mariano Gomes commissioned the San Caralampio bell in 1854.', 'The May 31, 1898 flag display placed the red field above the blue to signify a state of war.'],
      informationSources: ['https://bacoor.gov.ph/tourism/st-michael-the-archangel-church/', 'https://philhistoricsites.nhcp.gov.ph/registry_database/simbahan-ng-bacoor/', clupSource, tourismOfficeSource],
      dressCode: 'Wear modest clothing appropriate for an active place of worship. Remove hats when appropriate and keep phones silent during services.',
      photographyRules: 'Photography is generally appropriate outside services. Ask parish permission before using flash, tripods, drones, or photographing ceremonies.',
      prohibitedItems: 'Do not bring food or drinks into worship areas, create excessive noise, touch sacred objects, or disrupt Mass and parish activities.',
      petPolicy: 'Pets should remain outside worship areas unless they are trained service animals or parish permission is given.',
      safetyReminders: 'Watch for vehicle traffic around General Evangelista Street and take care on steps and wet stone surfaces.', emergencyContact,
      visitorTips: 'Check the parish schedule before visiting. Combine the church with Plaza de Padre Mariano Gomes and Bahay na Tisa, which are nearby.',
      publicationStatus: 'published', verifiedBy,
    },
  },
  {
    name: 'Bahay na Tisa ng Pamilya Cuenca',
    aliases: ['Bahay na Tisa (Cuenca Ancestral House)', 'Cuenca Ancestral House', 'Bahay na Tisa'],
    imageUrls: [
      'https://bacoor.gov.ph/wp-content/uploads/2024/02/441194134_456271863444664_6322108709324716287_n.jpg',
      'https://bacoor.gov.ph/wp-content/uploads/2024/02/440208800_1159056518872567_7344023968723390735_n.jpg',
    ],
    data: {
      shortSummary: 'A privately owned Important Cultural Property that served as headquarters of Emilio Aguinaldo’s Revolutionary Government in 1898.',
      municipality: 'Bacoor', barangay: 'Kaingin Digman', streetAddress: 'General Evangelista Street, Barangay Kaingin Digman, Bacoor City, Cavite',
      description: 'Bahay na Tisa ng Pamilya Cuenca is a historic ancestral house with roots in Bacoor’s Spanish colonial period. It became the headquarters of General Emilio Aguinaldo’s Revolutionary Government in July 1898 and hosted the Bacoor Assembly on August 1, 1898. The house is privately owned and is not open to the public, but its exterior and historical markers remain important parts of Bacoor’s heritage landscape.',
      category: 'Heritage House', latitude: 14.45967, longitude: 120.94280,
      openingDays: 'Private property; exterior viewing only', openingTime: '', closingTime: '', isAlwaysOpen: false,
      entranceFee: '', isFreeEntrance: true, contactNumber: tourismContact,
      websiteUrl: 'https://bacoor.gov.ph/tourism/bahay-na-tisa/', visitDuration: '15 to 30 minutes for exterior viewing',
      bestTimeToVisit: 'Daylight hours; arrange any educational visit through the tourism office', operatingStatus: 'temporarily_closed',
      historicalBackground: 'The Cuenca family’s stone house traces its history to the seventeenth century and was rebuilt after destruction during the 1762 British invasion. Its tiled roof was installed in 1892. The house survived an attempted burning by Spanish forces in 1897. On July 15, 1898, Emilio Aguinaldo transferred the Revolutionary Government to the house with Apolinario Mabini and cabinet officials. The August 1, 1898 Bacoor Assembly and signing of Mabini’s Acta de Independencia took place here. It received a historical marker in 1956 and was declared an Important Cultural Property on December 28, 2020.',
      culturalSignificance: 'The house was a working seat of the Revolutionary Government and a venue where leaders affirmed Philippine independence. It links Bacoor directly to the development of the First Philippine Republic and later hosted Roman Catholic worship during the Aglipayan schism.',
      yearEstablished: 'Rebuilt circa 1770; tiled roof installed 1892',
      importantPeople: ['General Emilio Aguinaldo', 'Apolinario Mabini', 'Don Juan Francisco Cuenca', 'Doña Candida Filio Chaves de Cuenca', 'Doña Marcela Cuenca', 'Felipe Buencamino', 'Mariano Trias'],
      importantEvents: ['1762 – Earlier house damaged during the British invasion.', '1892 – Traditional tile roofing installed.', 'July 15, 1898 – Revolutionary Government transferred to the house.', 'August 1, 1898 – Bacoor Assembly held and Acta de Independencia signed.', '1956 – Historical marker installed.', 'December 28, 2020 – Declared an Important Cultural Property.', '2023 – Included in the Philippine Nationhood Trail.'],
      interestingFacts: ['The house has been called an early revolutionary Malacañang.', 'More than one hundred government documents were issued while the Revolutionary Government was based there.', 'The house is still privately owned by the Cuenca family.'],
      informationSources: ['https://bacoor.gov.ph/tourism/bahay-na-tisa/', 'https://commons.wikimedia.org/wiki/Category:Cuenca_Ancestral_House', clupSource, tourismOfficeSource],
      dressCode: 'Wear ordinary respectful clothing suitable for exterior heritage viewing.',
      photographyRules: 'Photograph only from public areas unless the owners grant permission. Do not use drones or photograph private interiors without written consent.',
      prohibitedItems: 'Do not enter the property, touch the house or markers, block the road, or disturb residents.',
      petPolicy: 'Keep pets on public walkways and away from the private property.',
      safetyReminders: 'Remain on safe pedestrian areas and watch for traffic along General Evangelista Street.', emergencyContact,
      visitorTips: 'The house is not open to the public. View it respectfully from outside and combine the stop with nearby historical markers and churches.',
      publicationStatus: 'published', verifiedBy,
    },
  },
  {
    ...commonOutdoor,
    name: 'General Edilberto Evangelista Monument', aliases: ['Gen. Edilberto Evangelista Monument', 'Edilberto Evangelista Monument'],
    imageUrls: ['https://bacoor.gov.ph/wp-content/uploads/2024/02/5di-167.jpg'],
    data: {
      ...commonOutdoor,
      shortSummary: 'A monument honoring the revolutionary engineer and general who designed defenses and died during the 1897 Battle of Zapote Bridge.',
      municipality: 'Bacoor', barangay: 'Zapote 2', streetAddress: 'Zapote Heritage Area, Barangay Zapote 2, Bacoor City, Cavite',
      description: 'The General Edilberto Evangelista Monument honors the Filipino civil engineer, architect, and revolutionary general who designed fortifications for the Philippine Revolution. Located in Bacoor’s Zapote heritage area, it commemorates his leadership and sacrifice during the Battle of Zapote Bridge on February 17, 1897.',
      category: 'Monument / Memorial', latitude: 14.46395, longitude: 120.96620,
      websiteUrl: 'https://bacoor.gov.ph/tourism/tulay-ng-zapote/', visitDuration: '20 to 30 minutes', bestTimeToVisit: 'Weekday mornings or late afternoons during clear weather',
      historicalBackground: 'Edilberto Evangelista was born in Santa Cruz, Manila, on February 24, 1862. After studying at Colegio de San Juan de Letran, he went to Europe and completed civil engineering and architecture at Ghent in Belgium. He returned to join the Philippine Revolution and used his training to design trenches, forts, and barricades. He served as assistant captain-general under Emilio Aguinaldo and was killed while leading Filipino forces at Zapote Bridge on February 17, 1897.',
      culturalSignificance: 'The monument celebrates the role of engineering, planning, courage, and sacrifice in the Philippine Revolution. Evangelista is especially important to Bacoor because he died defending the Zapote position and a major city road bears his name.',
      yearEstablished: 'Commemorates the Battle of Zapote Bridge, 1897',
      importantPeople: ['General Edilberto Evangelista', 'General Emilio Aguinaldo', 'General Artemio Ricarte', 'General Mariano Noriel'],
      importantEvents: ['February 24, 1862 – Edilberto Evangelista was born.', '1890s – Studied engineering and architecture in Ghent, Belgium.', 'February 17, 1897 – Led defenses and died at the Battle of Zapote Bridge.', 'February 17 – Bacoor holds annual commemorative activities in the Zapote heritage area.'],
      interestingFacts: ['Evangelista was trained as both a civil engineer and architect.', 'His revolutionary defenses were admired for their advanced design.', 'General Evangelista Street in Bacoor was named in his honor.'],
      informationSources: ['https://bacoor.gov.ph/tourism/death-site-of-lt-gen-edilberto-evangelista/', 'https://bacoor.gov.ph/tourism/tulay-ng-zapote/', clupSource, tourismOfficeSource],
      safetyReminders: 'Stay within pedestrian spaces and remain alert near Aguinaldo Highway and the river. Avoid the area during flooding or heavy rain.',
      visitorTips: 'Visit together with Zapote Bridge, the battlefield markers, and the riverwalk to understand the complete story of the 1897 battle.',
      publicationStatus: 'published', verifiedBy,
    },
  },
  {
    ...commonOutdoor,
    name: 'Ginintuang Kasaysayan ng Lungsod ng Bacoor Monument', aliases: ['Ginintuang Kasaysayan Monument', 'Golden History of the City of Bacoor'],
    imageUrls: ['https://bacoor.gov.ph/wp-content/uploads/2024/05/ceee263e-ccb5-4b9f-9a7a-92a6a1f3a30c.jpg', 'https://bacoor.gov.ph/wp-content/uploads/2024/05/IMG_8491.jpg'],
    data: {
      ...commonOutdoor,
      shortSummary: 'A monumental tableau by National Artist Eduardo Castrillo depicting Bacoor’s history and transformation.',
      municipality: 'Bacoor', barangay: 'Bayanan', streetAddress: 'New Bacoor City Hall Access Road, Barangay Bayanan, Bacoor City, Cavite',
      description: 'Ginintuang Kasaysayan ng Lungsod ng Bacoor is a large sculpture mural tableau created by National Artist Eduardo S. Castrillo. Located near Bacoor City Hall, the artwork presents episodes, symbols, and transformations from the city’s past, connecting Bacoor’s revolutionary heritage with its growth into a modern city.',
      category: 'Monument / Memorial', latitude: 14.43087, longitude: 120.96723,
      websiteUrl: 'https://bacoor.gov.ph/tourism/ginintuang-kasaysayan-monument/', visitDuration: '20 to 40 minutes', bestTimeToVisit: 'Morning or late afternoon for comfortable viewing and photography',
      historicalBackground: 'The monument was commissioned as a public historical artwork for Bacoor. Eduardo S. Castrillo, a National Artist for Sculpture, created the monumental tableau to narrate the city’s development from the Spanish colonial period, through the revolutionary era, and into contemporary urban life.',
      culturalSignificance: 'The monument acts as a visual history lesson and civic landmark. It presents Bacoor’s identity through public art and gives residents and visitors an accessible way to reflect on the city’s role in national history.',
      yearEstablished: 'Modern civic monument',
      importantPeople: ['National Artist Eduardo S. Castrillo', 'The people and historical figures of Bacoor'],
      importantEvents: ['Creation of the monumental historical tableau.', 'Recognition as one of Bacoor’s principal heritage and tourism sites.'],
      interestingFacts: ['The monument was created by National Artist Eduardo Castrillo.', 'Its composition traces multiple periods of Bacoor’s history in a single public artwork.', 'It stands along the access road to the Bacoor Government Center.'],
      informationSources: ['https://bacoor.gov.ph/tourism/ginintuang-kasaysayan-monument/', clupSource, tourismOfficeSource],
      safetyReminders: 'Use designated pedestrian areas and stay alert for vehicles around the City Hall access road. Avoid climbing on the artwork.',
      visitorTips: 'Study the tableau from both near and far to identify its different historical scenes. Pair the visit with the Bacoor Government Center area.',
      publicationStatus: 'published', verifiedBy,
    },
  },
  {
    ...commonOutdoor,
    name: 'Prinsang Molino (Molino Dam)', aliases: ['Molino Dam', 'Prinsang Molino'],
    imageUrls: ['https://bacoor.gov.ph/wp-content/uploads/2024/05/GOPR0649-1.jpg', 'https://bacoor.gov.ph/wp-content/uploads/2024/05/DSCF3207.jpg'],
    data: {
      ...commonOutdoor,
      shortSummary: 'A long Spanish colonial gravity dam and irrigation structure completed in 1890 in Barangay Molino 3.',
      municipality: 'Bacoor', barangay: 'Molino III', streetAddress: 'Molino River, Barangay Molino III, Bacoor City, Cavite',
      description: 'Prinsang Molino, also known as Molino Dam, is a Spanish colonial irrigation dam in Barangay Molino III. Built with durable adobe, brick, tunnels, and canals, it formed part of the Recollect hacienda irrigation system. Its wall extends for roughly 350 meters and remains an important example of colonial water engineering.',
      category: 'Historical Site', latitude: 14.39862, longitude: 120.97980,
      websiteUrl: 'https://bacoor.gov.ph/tourism/prinza-dam/', visitDuration: '30 minutes to 1 hour', bestTimeToVisit: 'Dry-season mornings or late afternoons',
      historicalBackground: 'Spanish Recollect administrators began developing a network of colonial dams in Cavite in the late eighteenth century. Recollect lay brother Hilario Bernal designed Prinsang Molino, which collected water from river systems and distributed it through irrigation tunnels and canals. The structure was completed in 1890 and supported agricultural lands during dry periods.',
      culturalSignificance: 'The dam illustrates the engineering systems that sustained hacienda agriculture in Bacoor. Its scale, construction materials, and surviving wall make it an important industrial and agricultural heritage site.',
      yearEstablished: 'Completed in 1890',
      importantPeople: ['Recollect Brother Hilario Bernal', 'Augustinian Recollect administrators', 'Farmers of historic Bacoor haciendas'],
      importantEvents: ['Late 1700s – Recollect irrigation systems developed in Cavite.', '1890 – Prinsang Molino was completed.', 'Modern period – Bacoor began developing the dam wall as a heritage promenade.'],
      interestingFacts: ['The combined wall length is approximately 350 meters.', 'The system used tunnels and canals to store and distribute water during drought.', 'Prinsang Molino is different from Prinsang Ligas in San Nicolas.'],
      informationSources: ['https://bacoor.gov.ph/tourism/prinza-dam/', clupSource, tourismOfficeSource],
      safetyReminders: 'Do not climb the dam, cross barriers, or approach strong water flow. Stone and soil surfaces may be slippery, especially during rain.',
      visitorTips: 'Visit in dry, clear weather. Use only established paths and view the engineering structure from a safe distance.',
      publicationStatus: 'published', verifiedBy,
    },
  },
  {
    ...commonOutdoor,
    name: 'Prinsang Ligas (Prinza Dam)', aliases: ['Prinza Dam', 'Prinsang Ligas'],
    imageUrls: ['https://bacoor.gov.ph/wp-content/uploads/2024/05/IMG_8706.jpg'],
    data: {
      ...commonOutdoor,
      shortSummary: 'A colonial gravity dam and historic foot passage between Bacoor and Las Piñas, built for hacienda irrigation.',
      municipality: 'Bacoor', barangay: 'San Nicolas II', streetAddress: 'Ligas River, Barangay San Nicolas II, Bacoor–Las Piñas boundary',
      description: 'Prinsang Ligas, also called Prinza Dam, is a colonial gravity dam along the Ligas River near the Bacoor–Las Piñas boundary. Constructed with adobe walls and cobblestone flooring under Recollect Brother Roman Caballero, it irrigated rice fields of Hacienda de San Nicolas and continues to function as a pedestrian passage between communities.',
      category: 'Historical Site', latitude: 14.43804, longitude: 120.97539,
      websiteUrl: 'https://bacoor.gov.ph/tourism/prinsang-ligas/', visitDuration: '30 minutes to 1 hour', bestTimeToVisit: 'Dry-season mornings or late afternoons',
      historicalBackground: 'The Augustinian Recollects developed Prinsang Ligas as part of a gravity-fed irrigation network serving Hacienda de San Nicolas. Recollect Brother Roman Caballero supervised construction using adobe and cobblestone. The dam marked boundaries among historical haciendas in Bacoor, Las Piñas, and areas toward Muntinlupa and remains a local foot passage.',
      culturalSignificance: 'The structure preserves evidence of colonial-era hydrological engineering, hacienda agriculture, and long-standing travel links between Bacoor and Las Piñas.',
      yearEstablished: 'Spanish colonial period',
      importantPeople: ['Recollect Brother Roman Caballero', 'Augustinian Recollect administrators', 'Farmers of Hacienda de San Nicolas'],
      importantEvents: ['Construction as a gravity irrigation dam during the Spanish colonial period.', 'Continued use as a footbridge and passage between Bacoor and Las Piñas.', 'December 1, 2017 – Historical markers in the adjacent heritage area were unveiled.'],
      interestingFacts: ['Its floor includes cobblestone construction.', 'The dam follows the Ligas River from Sitio Bacod-na-Bato.', 'It still serves as a local pedestrian passage.'],
      informationSources: ['https://bacoor.gov.ph/tourism/prinsang-ligas/', 'https://philhistoricsites.nhcp.gov.ph/registry_database/molino-dam/', clupSource, tourismOfficeSource],
      safetyReminders: 'Use extreme caution near water and uneven historic surfaces. Do not cross during high water, flooding, heavy rain, or when access is restricted.',
      visitorTips: 'Combine the visit with Saint Ezekiel Moreno Park. Wear shoes with good grip and visit only during safe daylight conditions.',
      publicationStatus: 'published', verifiedBy,
    },
  },
  {
    ...commonOutdoor,
    name: 'Death Site of General Edilberto Evangelista', aliases: ['Death Site of Lt. Gen. Edilberto Evangelista', 'General Edilberto Evangelista Death Site', 'Battle of Bacoor Marker'],
    imageUrls: ['https://bacoor.gov.ph/wp-content/uploads/2024/05/Edilberto.jpg'],
    data: {
      ...commonOutdoor,
      shortSummary: 'The Zapote Bridge location commemorating where revolutionary engineer General Edilberto Evangelista was killed in 1897.',
      municipality: 'Bacoor', barangay: 'Zapote 2', streetAddress: 'Zapote Bridge, Aguinaldo Highway, Barangay Zapote 2, Bacoor City, Cavite',
      description: 'The Death Site of General Edilberto Evangelista marks the area at Zapote Bridge where the revolutionary engineer and general was killed during the Filipino victory against Spanish forces on February 17, 1897. A historical marker and the surrounding heritage complex preserve his memory and connect his sacrifice to the wider Battle of Zapote Bridge story.',
      category: 'Historical Site', latitude: 14.46410, longitude: 120.96631,
      websiteUrl: 'https://bacoor.gov.ph/tourism/death-site-of-lt-gen-edilberto-evangelista/', visitDuration: '20 to 30 minutes', bestTimeToVisit: 'Daylight hours during clear weather',
      historicalBackground: 'General Edilberto Evangelista used his European engineering training to design Filipino revolutionary defenses. During the Battle of Zapote Bridge on February 17, 1897, he helped lead the successful defense against Spanish troops but was killed in action. A historical marker installed in 1952 commemorated the battlefield and his death. The surrounding Zapote battlefield was later declared a National Historical Landmark.',
      culturalSignificance: 'The site honors a Filipino professional who placed his engineering knowledge at the service of the revolution. It is a place of remembrance for military courage, technical innovation, and sacrifice.',
      yearEstablished: 'Historical marker installed in 1952',
      importantPeople: ['General Edilberto Evangelista', 'General Emilio Aguinaldo', 'General Artemio Ricarte', 'General Mariano Noriel'],
      importantEvents: ['February 17, 1897 – Battle of Zapote Bridge and death of General Evangelista.', '1952 – Historical battlefield marker installed.', '2013 – Zapote battlefield declared a National Historical Landmark.', 'March 10, 2015 – National Historical Landmark marker unveiled.'],
      interestingFacts: ['Evangelista studied civil engineering and architecture in Ghent, Belgium.', 'He was known as a leading engineer of the Philippine Revolution.', 'A major Bacoor thoroughfare was named General Evangelista Street in his honor.'],
      informationSources: ['https://bacoor.gov.ph/tourism/death-site-of-lt-gen-edilberto-evangelista/', 'https://philhistoricsites.nhcp.gov.ph/registry_database/zapote-battlefield/', clupSource, tourismOfficeSource],
      safetyReminders: 'Remain in pedestrian areas and stay alert near Aguinaldo Highway, the bridge, and river edges. Avoid visiting during flooding or heavy rain.',
      visitorTips: 'Read this marker together with the Zapote battlefield markers and General Evangelista monument to understand the full sequence of the battle.',
      publicationStatus: 'published', verifiedBy,
    },
  },
  {
    name: 'Bacoor Eco-Park', aliases: ['Bacoor Family Eco-Park', 'Bacoor Eco Park'],
    imageUrls: ['https://bacoor.gov.ph/wp-content/uploads/2024/02/70da0250-9d1b-4106-bcc4-b7810879ecf8.jpg', 'https://bacoor.gov.ph/wp-content/uploads/2024/02/a294b787-abaa-4689-8dab-ebdddd998590.jpg'],
    data: {
      shortSummary: 'A half-hectare community park with playgrounds, sports facilities, huts, refreshment stalls, and a lagoon.',
      municipality: 'Bacoor', barangay: 'Molino V', streetAddress: 'Bahayang Pag-asa Phase 5, Barangay Molino V, Bacoor City, Cavite',
      description: 'Bacoor Eco-Park is a family-oriented public green space in Barangay Molino V. The approximately half-hectare park includes playground facilities, a basketball court, hut-style seating, refreshment stalls, a lagoon used for fishing and boating activities, and a multi-purpose building for community events and educational programs.',
      category: 'Park / Recreation', latitude: 14.39862, longitude: 120.97264,
      openingDays: 'Monday–Thursday 6:00 AM–7:00 PM; Friday–Sunday 6:00 AM–9:00 PM (confirm before visiting)', openingTime: '06:00', closingTime: '', isAlwaysOpen: false,
      entranceFee: '', isFreeEntrance: true, contactNumber: tourismContact,
      websiteUrl: 'https://bacoor.gov.ph/tourism/bacoor-family-eco-park/', visitDuration: '1 to 3 hours', bestTimeToVisit: 'Early morning or late afternoon; avoid heavy rain', operatingStatus: 'open',
      historicalBackground: 'The city developed Bacoor Eco-Park as a community recreation and environmental space. It opened as a public park in the late 2000s and has undergone improvements. On October 23, 2025, the city inaugurated an improved eco-park and new multi-purpose building to support recreation, workshops, educational programs, and community gatherings.',
      culturalSignificance: 'The park provides accessible green and recreational space in a highly urbanized city. Its facilities support family activities, physical wellness, community events, and environmental awareness.',
      yearEstablished: 'Opened circa 2009; improved facilities inaugurated in 2025',
      importantPeople: ['Residents of Barangay Molino V', 'Bacoor City Culture, History, Arts and Tourism Office', 'Bacoor City Engineering Office'],
      importantEvents: ['Circa 2009 – Eco-park opened to the public.', 'October 23, 2025 – Improved park and multi-purpose building blessed and inaugurated.'],
      interestingFacts: ['The park covers approximately half a hectare.', 'Facilities include a playground, basketball court, huts, refreshment stalls, and lagoon.', 'The multi-purpose building supports community and educational activities.'],
      informationSources: ['https://bacoor.gov.ph/tourism/bacoor-family-eco-park/', 'https://bacoor.gov.ph/latest-news/icymi-inauguration-and-multi-purpose-building-of-bacoor-eco-park/', clupSource, tourismOfficeSource],
      dressCode: 'Wear comfortable outdoor clothing and footwear. Bring sun or rain protection depending on the weather.',
      photographyRules: 'Personal photography is generally appropriate. Ask permission before photographing organized activities or using drones and professional equipment.',
      prohibitedItems: 'Do not litter, damage plants or facilities, swim in the lagoon, consume alcohol, or use equipment in ways that endanger others.',
      petPolicy: 'No official pet policy is published. Keep pets leashed and supervised and clean up after them.',
      safetyReminders: 'Supervise children around playground equipment, sports areas, and the lagoon. Avoid outdoor and boating activities during thunderstorms or heavy rain.', emergencyContact,
      visitorTips: 'Bring drinking water, insect protection, and sun protection. Contact the tourism office to confirm current hours and availability of boating or fishing activities.',
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
      const response = await fetch(url, { headers: { 'User-Agent': 'CaviteExplorer/1.0 (landmark data import)' } });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const contentType = response.headers.get('content-type') || '';
      if (!contentType.startsWith('image/')) throw new Error(`Unexpected content type ${contentType}`);
      const filename = `${randomUUID()}${extensionFor(url, contentType)}`;
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
    where: { municipality: { equals: 'Bacoor', mode: 'insensitive' }, name: { in: names } },
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
  const officialNames = [
    'Zapote Bridge and Battlefield',
    'Saint Michael the Archangel Parish Church',
    'Bahay na Tisa ng Pamilya Cuenca',
    'Plaza de Padre Mariano A. Gomes',
    'Saint Ezekiel Moreno Park',
    'General Edilberto Evangelista Monument',
    'Ginintuang Kasaysayan ng Lungsod ng Bacoor Monument',
    'Prinsang Molino (Molino Dam)',
    'Prinsang Ligas (Prinza Dam)',
    'Death Site of General Edilberto Evangelista',
    'Bacoor Eco-Park',
  ];
  const completed = await prisma.landmark.findMany({
    where: { municipality: 'Bacoor', name: { in: officialNames }, publicationStatus: 'published' },
    select: { name: true, barangay: true, category: true, images: true },
    orderBy: { name: 'asc' },
  });
  console.log(`\nPublished official Bacoor heritage sites: ${completed.length}/${officialNames.length}`);
  for (const place of completed) console.log(`- ${place.name} | ${place.barangay} | ${place.category} | ${place.images.length} image(s)`);
  if (completed.length !== officialNames.length || completed.some((place) => place.images.length === 0)) process.exitCode = 1;
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}).finally(async () => {
  await prisma.$disconnect();
});
