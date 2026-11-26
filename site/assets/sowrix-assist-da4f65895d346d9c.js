/* R46.3 SOWRIX Assist: curated visitor guidance + genuinely scoped business helpers.
   Zero third-party calls on open. No raw resumes or user prompts leave this browser.
   Optional count-only AI requires explicit server opt-in and database-authorized RPCs. */
(()=>{'use strict';
 if(window.SOWRIXR463)return;
 const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 const num=v=>Number.isSafeInteger(Number(v))?Math.max(0,Math.floor(Number(v))):0;
 const user=()=>window.__sxUser||null;
 const role=()=>String(user()?.role||'').toLowerCase();
 const rpc=async(name)=>{
  if(!user()?.id||!window.sowrixSupabase)throw Error('Sign in to your authorized workspace first.');
  const {data,error}=await window.sowrixSupabase.rpc(name,{});
  if(error)throw Error('Cannot access this summary. Check your permissions and R46.3 migration.');
  return data;
 };
 const PUBLIC_KNOWLEDGE={"version":"SOWRIX-PUBLIC-PHASE12-REVIEW-1","review":{"reviewed_date":"2026-11-18","review_scope":"Public website facts synchronized with the reference site data, the dedicated public pages and the published Careers recruitment flow","sources":["reference-build/standalone/05-data.js (SITE DATA: SERVICE_PILLARS, INDUSTRIES, WORK_STEPS, PROJECT_PROFILES, INSIGHTS)","reference-build/standalone/03-views.html (public page views)","reference-build/standalone/04-shell.html (contact and footer)","src/inline-3.js pageJob/pageJobApply/initJobForm (published role details and application copy)","src/sowrix-public-ui.js (Careers hero and published-listings presentation)","Published website copy and approved public navigation only"],"next_review":"Before any public launch milestone or business detail change"},"company":{"name":"SOWRIX Technologies","tagline":"One Technology Partner for Your Business.","overview":"SOWRIX Technologies provides six core solution areas: IT infrastructure and networks; software and applications; cybersecurity and data protection; hardware support and surveillance; digital marketing and growth analytics; and AI and automation integration.","email":"contact@sowrix.in","domain":"sowrix.in","phones":["+91 93447 61380","+91 96776 74641"],"locations":["Bengaluru","Chennai"],"process":"Discover → Analyze → Design → Implement → Support","lead_policy":"Send an enquiry through Contact. A confirmed save does not mean an email was delivered or a meeting was booked. The team confirms scope, pricing, schedule and availability."},"languages":{"supported":["English","Tamil","Tanglish"],"policy":"The visitor guide answers in the language of the question: Tamil script questions receive Tamil answers, Tanglish questions (Tamil written in Latin letters) receive Tanglish answers, and everything else receives English. Verified facts stay identical across languages; only the wording differs.","notes":"Business terms such as service names may remain in English inside Tamil and Tanglish answers when that is clearer for the reader."},"unknown_response":{"english":"I could not verify that detail from the published SOWRIX website information. Please contact the team for an accurate answer.","tamil":"இந்தக் கேள்விக்கான உறுதிப்படுத்தப்பட்ட விவரம் இணையதளத்தில் இல்லை. துல்லியமான தகவலுக்கு அணியைத் தொடர்பு கொள்ளுங்கள்.","tanglish":"Indha specific detail website-la verify aagala. Team kitte connect aagalaam — Contact page use pannunga."},"delivery_approach":[{"step":"01","title":"Consult & Discover","text":"It starts with a free consultation. We listen to what you are trying to build, fix or improve, then assess your current environment — infrastructure, systems, security posture and goals."},{"step":"02","title":"Design & Propose","text":"You receive a clear solution design with scoped deliverables, a transparent proposal and honest trade-offs — including what you do not need yet."},{"step":"03","title":"Build & Deploy","text":"Implementation with clear milestones: installation, configuration, testing, documentation and handover — phased to avoid disrupting your operations."},{"step":"04","title":"Operate & Improve","text":"AMC plans, monitoring and proactive maintenance keep systems healthy, with periodic reviews and iteration as your business grows."}],"services":[{"id":"it-infra-network","short_slug":"infra","name":"IT Infra & Network Solutions","description":"Enterprise IT infrastructure, networking, cloud foundations and ongoing support. Scope and availability are confirmed with the SOWRIX team.","capabilities":["Enterprise Networking","Cloud Infrastructure","Structured Cabling","Server Management"],"challenges":["Networks that grew organically and were never documented","Wi-Fi dead zones and congestion on multi-floor sites","Flat networks where guests, staff and devices share one subnet","Server rooms nobody owns — messy cabling, no monitoring"],"benefits":["A segmented, documented network that is fast and supportable","Infrastructure planned for capacity instead of crisis","One accountable team for servers, cabling, cloud and Wi-Fi","AMC-backed preventive care instead of reactive firefighting"],"keywords":["infrastructure","network","networking","cloud","IT support","cabling","server","wifi","firewall"],"page_link":"#/services/it-infra-network","consultation_link":"#contact"},{"id":"software-app-development","short_slug":"software","name":"Software & Application Development","description":"Custom software, web platforms, mobile applications and integrations designed around business workflows.","capabilities":["Custom Web Applications","Native iOS and Android Applications","Enterprise SaaS Platforms","API Integration"],"challenges":["Business logic trapped in spreadsheets and duplicated by hand","Tools that force teams to work the vendor's way","Disconnected systems that never talk to each other","Builds that ship and are then abandoned after launch day"],"benefits":["Software shaped around your actual workflow","Systems built to be maintained, extended and trusted","APIs and integrations that connect existing tools","A long-term maintenance partner, not a one-off build"],"keywords":["software","application","web app","website","mobile app","development","CRM","ERP","portal","SaaS"],"page_link":"#/services/software-app-development","consultation_link":"#contact"},{"id":"cybersecurity-data-protection","short_slug":"security","name":"Cybersecurity & Data Protection","description":"Cybersecurity and data-protection services. Specific assessments, controls and outcomes require a scoped review.","capabilities":["Threat Monitoring","Endpoint Security","Vulnerability Assessments","Compliance and Data Encryption"],"challenges":["Security treated as a one-time checkbox, not a practice","Alert noise without the context to act on it","Unpatched endpoints across a growing device fleet","Backups that exist but were never tested for recovery"],"benefits":["Layered defenses that find threats earlier","Honest assessments instead of checkbox compliance","Recovery plans that turn ransomware into an inconvenience","Encryption and access control aligned with your data"],"keywords":["cybersecurity","security","data protection","security assessment","endpoint","vulnerability","backup","encryption"],"page_link":"#/services/cybersecurity-data-protection","consultation_link":"#contact"},{"id":"hardware-support-surveillance","short_slug":"hardware","name":"Hardware Support & Surveillance","description":"Hardware support and authorized surveillance-system services, subject to site scope and supported equipment.","capabilities":["Enterprise Workstations","Printer Fleet Management","CCTV and IP Surveillance Systems","Biometric Access Control"],"challenges":["Printers and workstations with no clear owner to call","Camera coverage planned by guesswork instead of a site survey","Attendance and entry systems that do not match HR process","Hardware failures that bring the workday to a halt"],"benefits":["Hardware specified, installed and maintained by one team","Surveillance designed from a real coverage plan","Fleet costs brought under management","Support that keeps daily operations moving"],"keywords":["hardware","surveillance","CCTV","camera","NVR","printer","UPS","workstation","access control"],"page_link":"#/services/hardware-support-surveillance","consultation_link":"#contact"},{"id":"digital-marketing-growth-analytics","short_slug":"marketing","name":"Digital Marketing & Growth Analytics","description":"Digital marketing and growth analytics services; channel, scope and reporting are agreed with the customer.","capabilities":["Advanced SEO and AEO","Lead Generation Funnels","Conversion Rate Optimisation","Data-Driven Analytics"],"challenges":["Traffic that ranks but never becomes enquiries","Campaign spend with no honest attribution","An online presence that does not reflect the real business","Growth decisions made on opinion instead of evidence"],"benefits":["Full-funnel visibility from first click to enquiry","Campaigns wired to analytics from day one","Optimization that compounds quarter after quarter","Strategy grounded in measured results"],"keywords":["digital marketing","marketing","growth","analytics","SEO","AEO","advertising","lead generation","conversion"],"page_link":"#/services/digital-marketing-growth-analytics","consultation_link":"#contact"},{"id":"ai-automation-integration","short_slug":"ai","name":"AI & Automation Integration","description":"AI and automation integration as a core engine across suitable workflows, with human review and approved data boundaries.","capabilities":["Intelligent Process Automation","Custom LLM and AI Workflow Integrations","Predictive Business Analytics","Omnichannel Chatbots","Customer Service Automation"],"challenges":["Reports rebuilt manually every single week","Follow-ups that fall through the cracks","Data retyped between systems that should already talk","AI sold as magic instead of practical workflows"],"benefits":["Automation applied where it genuinely pays off","AI where it helps, plain logic where it does not","One intelligence layer across all six pillars","Faster operations without losing human oversight"],"keywords":["AI","automation","AI Core Engine","workflow","chatbot","LLM","integration","reports"],"page_link":"#/services/ai-automation-integration","consultation_link":"#contact"}],"pages":[{"id":"home","title":"Home","description":"Overview of SOWRIX Technologies: six service pillars, the SOWRIX AI engine, engagement approach, portfolio profiles and insights.","href":"#/"},{"id":"about","title":"About Us","description":"The SOWRIX story, values and connected technology approach — one partner for the whole technology picture.","href":"#/about"},{"id":"services","title":"Services","description":"All six solution pillars with business descriptions, technical deliverables, use cases, industries and consultation links.","href":"#/services"},{"id":"industries","title":"Industries","description":"Sector-specific technology delivery for small businesses, startups, corporate offices, hotels, residential communities, retail, healthcare, education and manufacturing.","href":"#/industries"},{"id":"solutions","title":"Solutions","description":"How the six pillars and capability groups combine into complete answers for real business problems, plus the Defensowrix platform direction.","href":"#/solutions"},{"id":"portfolio","title":"Portfolio","description":"Representative engagement profiles describing typical project scope and deliverables — network modernization, surveillance rollout, custom platforms and security visibility.","href":"#/portfolio"},{"id":"insights","title":"Blog & Insights","description":"Practical articles on networking, growth marketing, cybersecurity and software decisions, written from real delivery experience.","href":"#/insights"},{"id":"defensowrix","title":"Defensowrix (Coming Soon)","description":"Unified IT monitoring and cybersecurity visibility platform under development. Planned capabilities only — not available for purchase or production onboarding.","href":"#/defensowrix"},{"id":"contact","title":"Contact","description":"Free consultation enquiry with the official email contact@sowrix.in, phone numbers and Bengaluru/Chennai presence.","href":"#contact"},{"id":"careers","title":"Careers","description":"Published openings and application instructions. An application or interview is not guaranteed.","href":"/careers"}],"suggested_questions":{"default":[{"label":"All services","question":"What services do you provide?"},{"label":"Website","question":"I need a website"},{"label":"Marketing","question":"Digital marketing"},{"label":"Contact","question":"What is your phone and email?"}],"about":[{"label":"About","question":"What does SOWRIX do?"},{"label":"Process","question":"How does SOWRIX work?"},{"label":"Services","question":"What services do you provide?"}],"services":[{"label":"Services","question":"What services do you provide?"},{"label":"Choose","question":"Which service fits my need?"},{"label":"Contact","question":"How can I discuss a project?"}],"service":[{"label":"Overview","question":"What does this service include?"},{"label":"Challenges","question":"What business challenges does this solve?"},{"label":"Process","question":"How do projects like this start?"},{"label":"Contact","question":"How can I discuss this service?"}],"industries":[{"label":"Industries","question":"Which industries do you serve?"},{"label":"SMB","question":"Do you support small businesses?"},{"label":"Contact","question":"How can I discuss my industry needs?"}],"solutions":[{"label":"Solutions","question":"What solutions does SOWRIX provide?"},{"label":"AI Core Engine","question":"What is the AI Core Engine?"},{"label":"Start","question":"How do I start a project?"}],"portfolio":[{"label":"Profiles","question":"What engagement profiles do you publish?"},{"label":"Results","question":"Do you guarantee project results?"},{"label":"Scope","question":"How do I scope a project?"}],"insights":[{"label":"Topics","question":"What topics do you write about?"},{"label":"Segmentation","question":"Tell me about network segmentation"},{"label":"Contact","question":"How can I discuss these ideas with the team?"}],"defensowrix":[{"label":"Overview","question":"What is DEFENSOWRIX?"},{"label":"Status","question":"Is DEFENSOWRIX available now?"},{"label":"Contact","question":"How can I contact SOWRIX?"}],"contact":[{"label":"Start","question":"How do I start a project?"},{"label":"Details","question":"What should I include in an enquiry?"},{"label":"Email","question":"What is the SOWRIX email?"}],"careers":[{"label":"Open roles","question":"What careers are available?"},{"label":"How to apply","question":"How do I apply for a role?"},{"label":"Resume","question":"How do I submit my resume?"},{"label":"Contact","question":"How can I contact SOWRIX?"}]},"topics":[{"id":"careers-openings","title":"Careers","answer":"The Careers page lists every published opening with its department, location and employment type. Use the search box to find a role by title and the location filter to narrow the list. If nothing matches your search, check back later — only published vacancies are shown.","answer_tamil":"வேலைவாய்ப்புப் பக்கத்தில் வெளியிடப்பட்ட ஒவ்வொரு பணியிடமும் துறை, இடம் மற்றும் பணியின் வகையுடன் பட்டியலிடப்படுகிறது. தலைப்பின் மூலம் தேடலாம்; இட வடிகட்டியைப் பயன்படுத்தி பட்டியலைச் சுருக்கலாம். பொருத்தமான பணியிடம் இல்லையென்றால் பின்னர் மீண்டும் பாருங்கள் — வெளியிடப்பட்ட வேலைவாய்ப்புகள் மட்டுமே இங்கே காட்டப்படும்.","answer_tanglish":"Careers page-la publish panna ella openings-um department, location, employment type oda irukkum. Title vechu search pannalaam; location filter use panni list-ah kurakalaam. Ippo onnum match aagala-na appuram thirumpa paarunga — publish panna vacancies dhaan inka kaatuvom.","keywords":["open roles","openings","vacancy","vacancies","position","current openings","job openings","available roles","velai vakku","வேலைவாய்ப்பு","பணியிடம்"],"href":"/careers"},{"id":"careers-how-to-apply","title":"How to Apply","answer":"Open a published role on the Careers page and select Apply Now. The published steps are: 01 fill out the application form; 02 upload your resume (PDF / DOC / DOCX); 03 the HR team reviews applications within 5–7 working days; 04 shortlisted candidates are contacted by email. An application or interview is not guaranteed.","answer_tamil":"வேலைவாய்ப்புப் பக்கத்தில் உள்ள பணியிடத்தைத் திறந்து 'Apply Now' ஐத் தேர்ந்தெடுங்கள். வெளியிடப்பட்ட படிகள்: 01 விண்ணப்பப் படிவத்தை நிரப்புங்கள்; 02 உங்கள் சுயவிவரக் கோப்பை (PDF / DOC / DOCX) பதிவேற்றுங்கள்; 03 மனிதவள அணி 5–7 பணி நாட்களில் விண்ணப்பங்களை ஆய்வு செய்யும்; 04 சுருக்கப்பட்ட வேட்பாளர்கள் மின்னஞ்சல் மூலம் தொடர்பு கொள்ளப்படுவர். விண்ணப்பம் அல்லது நேர்காணல் உறுதி செய்யப்படாது.","answer_tanglish":"Careers page-la oru published role open panni 'Apply Now' click pannunga. Published steps: 01 application form fill pannunga; 02 resume-ah (PDF / DOC / DOCX) upload pannunga; 03 HR team 5–7 working days-la applications-ah review pannum; 04 shortlisted candidates-ku email-la contact panranga. Application illa interview guarantee illa.","keywords":["how to apply","how do i apply","how can i apply","apply for a job","apply for a role","apply for this role","application form","submit application","apply pann","epdi apply","eppadi apply","விண்ணப்பிக்க","விண்ணப்பிப்பது","விண்ணப்பம்"],"href":"/careers"},{"id":"careers-resume","title":"Resume Submission","answer":"Upload your resume through the application form of a published role. Accepted files are PDF, DOC or DOCX up to 5 MB. Your resume is stored on secured systems that only the recruitment team can access, and it is never published publicly.","answer_tamil":"வெளியிடப்பட்ட பணியிடத்தின் விண்ணப்பப் படிவம் வழியாக உங்கள் சுயவிவரக் கோப்பைப் பதிவேற்றுங்கள். PDF, DOC அல்லது DOCX கோப்புகள் 5 MB வரை ஏற்கப்படுகின்றன. உங்கள் சுயவிவரம் பாதுகாப்பான கணினிகளில் சேமிக்கப்படுகிறது; அணுக பணியமர்த்தல் அணியால் மட்டுமே முடியும், பொது இடத்தில் வெளியிடப்படாது.","answer_tanglish":"Published role oda application form vazhiya resume upload pannunga. PDF, DOC illa DOCX — 5 MB varaikkum ok. Unga resume secured systems-la dhaan store aagum; recruitment team mattum dhaan paakanga, publicly eppovum publish pannamaatanga.","keywords":["resume","cv","cover letter","upload resume","resume upload","resume format","file size","5 mb","pdf","docx","சுயவிவரம்","பதிவேற்ற"],"href":"/careers"},{"id":"careers-process","title":"Recruitment Process","answer":"Published recruitment process: the HR team reviews each application within 5–7 working days, and shortlisted candidates are contacted by email. This guide sees published information only — it cannot check application records or promise an interview.","answer_tamil":"வெளியிடப்பட்ட பணியமர்த்தல் செயல்முறை: மனிதவள அணி ஒவ்வொரு விண்ணப்பத்தையும் 5–7 பணி நாட்களில் ஆய்வு செய்கிறது; சுருக்கப்பட்ட வேட்பாளர்கள் மின்னஞ்சல் மூலம் தொடர்பு கொள்ளப்படுகிறார்கள். இந்த வழிகாட்டிக்கு வெளியிடப்பட்ட தகவல்கள் மட்டுமே கிடைக்கும் — விண்ணப்பப் பதிவுகளைச் சரிபார்க்கவோ நேர்காணலை உறுதி செய்யவோ முடியாது.","answer_tanglish":"Published recruitment process: HR team oru application-um 5–7 working days-la review pannum, shortlisted candidates-ku email varum. Intha guide-ku published information mattum dhaan theriyum — application records check panna mudiyathu, interview-u guarantee panna mudiyathu.","keywords":["recruitment process","hiring process","shortlist","shortlisted","application status","interview","selection process","after applying","நேர்காணல்","தேர்வு செயல்முறை"],"href":"/careers"},{"id":"careers-eligibility","title":"Role Requirements","answer":"Every published role lists its own requirements, key skills and experience on its detail page. Open the role from the Careers page and review the Requirements section before applying; the assistant cannot pre-approve eligibility.","answer_tamil":"ஒவ்வொரு வெளியிடப்பட்ட பணியிடமும் அதன் விவரப் பக்கத்தில் தேவைகள், முக்கியத் திறன்கள் மற்றும் அனுபவத்தைப் பட்டியலிடுகிறது. விண்ணப்பிக்கும் முன் வேலைவாய்ப்புப் பக்கத்திலிருந்து பணியிடத்தைத் திறந்து Requirements பகுதியைப் பாருங்கள்; இந்த வழிகாட்டியால் தகுதியை முன்கூட்டியே உறுதிப்படுத்த முடியாது.","answer_tanglish":"Published role oda detail page-la adheoda requirements, key skills, experience ellaam irukkum. Careers page-la irunthu role-ah open panni Requirements section-ah paathu apply pannunga; eligibility-ah intha guide mudhal-la approve pannaathu.","keywords":["eligibility","job requirements","role requirements","qualification","qualifications","experience required","skills required","who can apply","தகுதி"],"href":"/careers"},{"id":"careers","title":"Careers","answer":"Find published openings and application instructions on the Careers page. An application or interview is not guaranteed.","keywords":["career","careers","job","jobs","internship","intern","apply","hiring","recruitment","வேலை","velai","career page"],"href":"/careers"},{"id":"defensowrix","title":"DEFENSOWRIX Coming Soon","answer":"DEFENSOWRIX is under development and is not available for purchase or production onboarding. Its public page lists planned capabilities only. No product release date has been announced. The Early Access request program is not open yet; SOWRIX will announce it after its secure workflow is tested.","keywords":["defensowrix","early access","monitoring product","NOC","SOC","copilot","incident management"],"href":"/#/defensowrix"},{"id":"client","title":"Client Portal","answer":"Existing clients can sign in to see authorized records for projects, support tickets, invoices, service contracts (AMC) and documents. This public chatbot cannot view private account data.","keywords":["client portal","client login","my invoice","my project","my ticket","my amc","client dashboard","portal","sign in","login","account"],"href":"/app#/login"},{"id":"portfolio","title":"Portfolio","answer":"The Portfolio page lists representative engagement profiles — the typical scope and deliverables of SOWRIX projects. Customer names or quantified results should only be relied on when published and verified.","keywords":["portfolio","case study","case studies","previous work","past project","completed projects","projects done"],"href":"#/portfolio"},{"id":"industries","title":"Industries","answer":"The Industries page shows where SOWRIX adapts its six solution pillars — from small businesses and startups to hotels, healthcare, education and manufacturing. For an industry-specific implementation, confirm details with the team.","keywords":["industries","industry","business sector","sector","hospital","manufacturing","education","retail"],"href":"#/industries"},{"id":"solutions","title":"Solutions","answer":"The Solutions page shows how the six pillars and SOWRIX capability groups combine into complete answers for real business problems. Share your requirements to get a tailored recommendation.","keywords":["solutions","solution page","business solution"],"href":"#/solutions"},{"id":"insights","title":"Blog & Insights","answer":"The Blog & Insights page collects practical SOWRIX articles on networking, growth marketing, cybersecurity and software decisions — written from real delivery experience.","keywords":["blog","insights","article","articles","network segmentation","AEO","answer engine"],"href":"#/insights"},{"id":"about","title":"About Us","answer":"The About page explains the SOWRIX story, values and connected technology approach — one partner for the whole technology picture.","keywords":["about","about page","story","values","who we are"],"href":"#/about"},{"id":"services","title":"Services","answer":"The Services page details all six solution pillars — infrastructure, software, cybersecurity, hardware and surveillance, digital marketing, and AI & automation — with deliverables, use cases and consultation links.","keywords":["services","services page","pillars","solution pillars"],"href":"#/services"},{"id":"contact","title":"Contact","answer":"Use the Contact section to request a free consultation. The official email is contact@sowrix.in and the team can also be reached on the published phone numbers.","keywords":["contact page","free consultation","enquiry","enquire","talk to team"],"href":"#contact"},{"id":"status","title":"Service Status","answer":"See the public Status page for reviewed service updates and maintenance notices. It may not list every incident; ask the team about a particular service.","keywords":["outage","downtime","uptime","maintenance notice","service status","system status"],"href":"/status.html"},{"id":"privacy","title":"Privacy and Trust","answer":"Read the SOWRIX Privacy and Trust pages for published information. The visitor chatbot does not have permission to access client records, passwords, or private documents.","keywords":["privacy","data protection","trust","terms","gdpr","information security policy"],"href":"/privacy"}],"conversation":{"tanglish_markers":["enaku","enakku","ennaku","epdi","eppadi","enna","venum","unga","evlo","evalo","iruka","irukku","kidaikuma","pannunga","pannanum","sollunga","pathi","enga","ku","la"],"corrections":{"defensowrx":"defensowrix","defensowrrix":"defensowrix","prise":"price","prcing":"pricing","webiste":"website","webstie":"website","automtion":"automation","cybersecuirty":"cybersecurity","consulation":"consultation","carrer":"career","suport":"support"},"follow_up":["that","this","it","those","these","same","idhu","adhu","ithu","அது","இது","அதற்கு","இதற்கு"],"service_signals":{"it-infra-network":["wifi","wi fi","dead zones","slow network","network drops","வேகம்","நெட்வொர்க்","இணையம்"],"software-app-development":["websites","online store","build an app","replace spreadsheets","spreadsheet","invoice app","இணையதளம்","செயலி"],"cybersecurity-data-protection":["ransomware","phishing","data loss","recover backups","தரவு பாதுகாப்பு","இணையப் பாதுகாப்பு"],"hardware-support-surveillance":["printers","cameras","door access","வேலைநிலையம்","கேமரா","அச்சுப்பொறி"],"digital-marketing-growth-analytics":["search ranking","more leads","search traffic","campaigns","விளம்பரம்","சந்தைப்படுத்தல்"],"ai-automation-integration":["automate","repetitive tasks","manual reporting","weekly reports","manual follow ups","தானியக்கம்","செயற்கை நுண்ணறிவு"]},"cards":{"product":{"keywords":["defensowrix","early access","monitoring product","noc","soc","முன்கூட்டிய அணுகல்","ஆரம்ப அணுகல்"],"href":"/#defensowrix-request","label":"Request DEFENSOWRIX","tamil":"DEFENSOWRIX உருவாக்கத்தில் உள்ளது (Coming Soon). இப்போது வாங்கவோ பயன்படுத்தவோ முடியாது. Early Access திறக்கப்படவில்லை. Request DEFENSOWRIX படிவத்தில் உங்கள் நிறுவனத்தின் தேவையைத் தெரிவிக்கலாம்; இது தயாரிப்பு அணுகலையோ சந்தாவையோ உறுதி செய்யாது.","tanglish":"DEFENSOWRIX innum development-la irukku (Coming Soon). Ippodhu purchase alladhu production onboarding available illai. Early Access open aagala. Request DEFENSOWRIX form-la business requirements share pannalaam; idhu access, subscription reservation, alladhu availability guarantee illa."},"pricing":{"keywords":["price","pricing","how much","cost","costing","charges","budget","quote","quotation","evlo","evalo","விலை","கட்டணம்","செலவு"],"href":"/#contact","label":"Contact SOWRIX","english":"SOWRIX does not publish a fixed price for {subject}. The team reviews requirements before confirming an estimate. The consultation enquiry is free; it is not a quote or a booking.","tamil":"{subject} தொடர்பான நிர்ணயிக்கப்பட்ட விலை வெளியிடப்படவில்லை. தேவைகளை மதிப்பாய்வு செய்த பின்பே குழு மதிப்பீட்டை உறுதிசெய்யும். ஆலோசனைக்கான கோரிக்கையை இலவசமாக அனுப்பலாம்.","tanglish":"{subject} ku fixed price publish pannala. Requirements review pannina piragu team estimate confirm pannum. Consultation enquiry free; adhu booking illai."},"domain":{"keywords":["official domain","official website","sowrix in","website address","domain name","அதிகாரப்பூர்வ இணையதளம்"],"href":"/","label":"SOWRIX homepage","english":"The official SOWRIX Technologies domain is {domain}. The public business email is {email}.","tamil":"SOWRIX Technologies நிறுவனத்தின் அதிகாரப்பூர்வ இணையதளம் {domain}. வணிகத் தொடர்பு மின்னஞ்சல் {email}.","tanglish":"SOWRIX Technologies-oda official website {domain}. Business contact email {email}."},"support":{"keywords":["customer support","support ticket","raise a ticket","technical support","existing client","help with my project","account help","வாடிக்கையாளர் ஆதரவு","உதவி கோரிக்கை"],"href":"/app#/login","label":"Sign in to the Client Portal","english":"If you have an assigned Client Portal account, sign in and open Support tickets. If you cannot sign in or do not have portal access, contact {email}. This chat cannot view or change your records.","tamil":"Client Portal கணக்கு உங்களுக்கு வழங்கப்பட்டிருந்தால், உள்நுழைந்து Support tickets பகுதியைத் திறக்கவும். உள்நுழைய முடியாவிட்டால் {email} முகவரியைத் தொடர்புகொள்ளுங்கள். இந்த உரையாடலில் உங்கள் பதிவுகளைப் பார்க்கவோ மாற்றவோ முடியாது.","tanglish":"Ungalukku Client Portal access irundhaal sign in panni Support tickets open pannunga. Access illaina {email} ku contact pannunga. Indha chat-la unga records paarkkavo maatravo mudiyadhu."},"ai_core":{"keywords":["ai core engine","sowrix ai engine","ai core","ai engine"],"href":"/#/services/ai","label":"AI & Automation Integration","english":"The SOWRIX AI Core Engine describes the intelligence and automation approach across its service pillars. The team can assess suitable integrations, reporting and repetitive workflows. It does not mean a separately purchasable product or a guarantee of live AI in this chat.","tamil":"SOWRIX AI Core Engine என்பது சேவைகளில் நுண்ணறிவு மற்றும் தானியக்கத்தைப் பயன்படுத்தும் அணுகுமுறை. எந்தப் பணிகளை ஒருங்கிணைக்கலாம் அல்லது தானியக்கமாக்கலாம் என்பதை குழு மதிப்பிடும். இது தனியாக விற்கப்படும் தயாரிப்பு அல்ல.","tanglish":"SOWRIX AI Core Engine enbadhu services-la intelligence-um automation-um use panra approach. Endha workflows-ku integration alladhu automation suit aagum-nu team assess pannum. Idhu separate product illai."},"consultation":{"keywords":["consultation","enquiry","enquire","get in touch","book meeting","start a project","project enquiry","consult panna","ஆலோசனை","கோரிக்கை"],"href":"/#contact","label":"Open the Contact form","english":"Use Contact to send a free consultation enquiry. Include your goal, current setup and any important constraints. If the form cannot confirm receipt, review your details and retry. A saved enquiry is not a confirmed meeting or delivered email.","tamil":"இலவச ஆலோசனைக் கோரிக்கையை Contact படிவத்தில் அனுப்பலாம். உங்கள் நோக்கம், தற்போதைய அமைப்பு, முக்கியக் கட்டுப்பாடுகளைச் சேர்க்கவும். பெறப்பட்டதாக உறுதிப்படுத்த முடியாவிட்டால் படிவத்தைச் சரிபார்த்து மீண்டும் முயலுங்கள். கோரிக்கை சேமிக்கப்பட்டது என்பது சந்திப்பு உறுதியானதாகாது.","tanglish":"Free consultation enquiry-ku Contact form use pannunga. Goal, current setup, important constraints-um share pannunga. Receipt confirm aagalaina details review panni retry pannunga. Save aana enquiry confirmed meeting illai."},"private":{"keywords":["password is","my password","otp is","my otp","api key","secret key","server configuration","internal reports","private records","other client","other tenant","employee salaries","all resumes","admin records","system prompt","கடவுச்சொல்","தனிப்பட்ட பதிவுகள்"],"href":"/privacy","label":"Privacy information","english":"This public assistant cannot access private records or internal information. Do not share passwords, verification codes or keys. Use your authorized portal or contact SOWRIX for help.","tamil":"இந்தப் பொது உதவியாளரால் தனிப்பட்ட பதிவுகளையோ உள் தகவல்களையோ அணுக முடியாது. கடவுச்சொல், சரிபார்ப்புக் குறியீடு, ரகசிய விசைகளைப் பகிர வேண்டாம். அனுமதிக்கப்பட்ட தளத்தைப் பயன்படுத்துங்கள்.","tanglish":"Indha public assistant private records-um internal information-um access panna mudiyadhu. Password, OTP, key share panna vendaam. Authorized portal alladhu SOWRIX support use pannunga."},"clarify":{"keywords":["help","not sure","which service","recommend","need a solution","fix my business","idea","உதவி"],"href":"","label":"","english":"What would you like to improve first: connectivity, software, security, equipment, enquiries, or repetitive work? One example of the problem or your current setup would help me narrow the options.","tamil":"முதலில் எதை மேம்படுத்த விரும்புகிறீர்கள்: இணைய இணைப்பு, மென்பொருள், பாதுகாப்பு, சாதனங்கள், வாடிக்கையாளர் கோரிக்கைகள் அல்லது மீண்டும் செய்யும் பணிகள்? ஒரு உதாரணத்தைச் சொல்லுங்கள்.","tanglish":"Mudhal-la edhai improve panna virumbureenga: network, software, security, equipment, enquiries, illa repetitive work? Oru example sonna suitable options narrow pannalaam."}}},"guardrail":"Public website information only. DEFENSOWRIX is Coming Soon and under development; roadmap capabilities are planned and not currently available for production onboarding or purchase. Early Access is closed. Do not invent pricing, certifications, partnerships, addresses, delivery dates or guaranteed outcomes. Never access private account data.","products":[{"id":"defensowrix","name":"DEFENSOWRIX","availability":"under_development","answer":"DEFENSOWRIX is Coming Soon and under development. Infrastructure monitoring, AI-assisted IT operations and defensive security monitoring are planned. It is not available for production onboarding or purchase. No release date has been announced. Early Access requests are not open yet. Use Request DEFENSOWRIX to share your business interest. A request does not provide access, reserve a subscription or guarantee availability.","planned_capabilities":["Infrastructure Monitoring","Network Monitoring","Firewall Health","Endpoint Monitoring","Hardware Monitoring","Authorized CCTV and NVR Health","Printer and UPS Monitoring","NAS and Storage Monitoring","Backup Health","AI Engineer Copilot","AI-Assisted Troubleshooting","Defensive Security Operations","NOC Dashboard","Incident Management","Intelligent Alerts","Analytics and Reporting","Multi-Site Monitoring"],"early_access":"not_open"}],"social_links":[{"name":"X (Twitter)","url":"https://x.com/sowrixtech"},{"name":"YouTube","url":"https://www.youtube.com/@Sowrix"}]};
  const normal=q=>String(q||'').toLowerCase().normalize('NFKC').replace(/[\u200b\u200c\u200d]/g,'').replace(/[^\p{L}\p{M}\p{N}]+/gu,' ').trim();
 const includesPhrase=(query,phrase)=>{const needle=normal(phrase);return needle&&(' '+normal(query)+' ').includes(' '+needle+' ');};
 const any=(query,words)=>words.some(word=>includesPhrase(query,word));
 const contactLink={href:'#contact',label:'Contact SOWRIX'};
 const servicesLink={href:'#/services',label:'View all services'};
 const pageAssistant=()=>{
  const hash=String(location.hash||'').toLowerCase(),path=String(location.pathname||'').toLowerCase();
  const SUGGESTED=PUBLIC_KNOWLEDGE.suggested_questions||{};
  const prompts=(key,fall)=>{const list=SUGGESTED[key];return Array.isArray(list)&&list.length?list.slice(0,4).map(x=>[(x&&x.label)||String(x.question||x).slice(0,20),(x&&x.question)||x]):fall;};
  const serviceNames={
   'infra':'IT Infrastructure & Network Solutions','it-infra-network':'IT Infrastructure & Network Solutions',
   'software':'Software & Application Development','software-app-development':'Software & Application Development',
   'security':'Cybersecurity & Data Protection','cybersecurity-data-protection':'Cybersecurity & Data Protection',
   'hardware':'Hardware Support & Surveillance','hardware-support-surveillance':'Hardware Support & Surveillance',
   'marketing':'Digital Marketing & Growth Analytics','digital-marketing-growth-analytics':'Digital Marketing & Growth Analytics',
   'ai':'AI & Automation Integration','ai-automation-integration':'AI & Automation Integration'
  };
  const match=hash.match(/#\/services\/([^/?]+)/),service=match&&serviceNames[match[1]];
  if(service)return {description:`${service} guidance · verified website information`,prompts:prompts('service',[[service,`What does SOWRIX provide for ${service}?`],['Process','How do projects like this start?'],['Contact','How can I discuss this service?']])};
  if(hash.includes('defensowrix'))return {description:'DEFENSOWRIX · Coming Soon information only',prompts:prompts('defensowrix',[['Overview','What is DEFENSOWRIX?'],['Status','Is DEFENSOWRIX available now?'],['Contact','How can I contact SOWRIX?']])};
  if(path==='/careers'||hash.includes('careers'))return {description:'Careers and recruitment guidance · no application data is exposed',prompts:prompts('careers',[['Open roles','What careers are available?'],['Process','How do I apply?'],['Contact','How can I contact SOWRIX?']])};
  if(hash.includes('contact'))return {description:'Consultation guidance · your message is submitted only through the normal form',prompts:prompts('contact',[['Start','How do I start a project?'],['Details','What should I include in an enquiry?'],['Email','What is the SOWRIX email?']])};
  if(hash.includes('about'))return {description:'About SOWRIX · verified company and process information',prompts:prompts('about',[['About','What does SOWRIX do?'],['Process','How does SOWRIX work?'],['Services','What services do you provide?']])};
  if(hash.includes('industries'))return {description:'Industries guidance · sector-specific delivery across the six pillars',prompts:prompts('industries',[['Industries','Which industries do you serve?'],['SMB','Do you support small businesses?'],['Contact','How can I discuss my industry needs?']])};
  if(hash.includes('solutions'))return {description:'Solutions guidance · how the pillars combine into complete answers',prompts:prompts('solutions',[['Solutions','What solutions does SOWRIX provide?'],['AI Core Engine','What is the AI Core Engine?'],['Start','How do I start a project?']])};
  if(hash.includes('portfolio'))return {description:'Portfolio guidance · representative engagement profiles only',prompts:prompts('portfolio',[['Profiles','What engagement profiles do you publish?'],['Results','Do you guarantee project results?'],['Scope','How do I scope a project?']])};
  if(hash.includes('insights'))return {description:'Blog & insights guidance · practical articles from the SOWRIX team',prompts:prompts('insights',[['Topics','What topics do you write about?'],['Segmentation','Tell me about network segmentation'],['Contact','How can I discuss these ideas with the team?']])};
  if(hash.includes('services'))return {description:'Services guidance · six verified SOWRIX solution areas',prompts:prompts('services',[['Services','What services do you provide?'],['Choose','Which service fits my need?'],['Contact','How can I discuss a project?']])};
  return {description:'Your technology guide · published SOWRIX information',prompts:([['Explore services','What services do you provide?'],['Find a solution','Which service fits my need?'],['DEFENSOWRIX','What is DEFENSOWRIX?'],['Contact','What is your phone and email?']])};
 };
  const answerFor=(question,context={})=>{
   const kb=PUBLIC_KNOWLEDGE,co=kb.company,conv=kb.conversation;
   const q=normal(question).split(' ').map(word=>Object.hasOwn(conv.corrections,word)?conv.corrections[word]:word).join(' ');
   const tamil=/[\u0b80-\u0bff]/u.test(q),tanglish=any(q,conv.tanglish_markers);
   const say=(plain,ta,tl)=>tamil?(ta||plain):tanglish?(tl||plain):plain;
   const result=(text,link=null,service='',product=false)=>({text,href:link?.href?.replace(/^#/,'/#')||'',link:link?.label||'',service,product});
   const matches=(name)=>any(q,conv.cards[name].keywords);
   const ranked=kb.services.map(s=>({s,score:[...new Set([...s.keywords,...conv.service_signals[s.id]])].reduce((n,w)=>n+(includesPhrase(q,w)?(normal(w).includes(' ')?4:2):0),0)})).filter(x=>x.score>0).sort((a,b)=>b.score-a.score);
   const pageMatch=location.hash.match(/^#\/services\/([^/?]+)/)?.[1];
   const ref=any(q,conv.follow_up);
   const detail=any(q,['benefits','advantages','features','capabilities','what is included','uses','nanmai','enna benefit','பயன்கள்','அம்சங்கள்']);
   const continuation=ref||detail||matches('pricing')||any(q,['how long','timeline','duration','process','next steps','எப்படி தொடங்குவது']);
   const active=ranked[0]?.s||kb.services.find(s=>(continuation&&s.id===context.service)||(continuation&&!context.service&&(s.id===pageMatch||s.short_slug===pageMatch)));
   const card=(name,english,service='')=>{
    const c=conv.cards[name],fields={subject:active?.name||say('this project','இந்தத் திட்டம்','indha project'),domain:co.domain,email:co.email};
    return result(say(english||c.english,c.tamil,c.tanglish).replace(/\{(\w+)\}/g,(_,key)=>fields[key]),c,service,name==='product');
   };
   const unknown=()=>result(say(kb.unknown_response.english,kb.unknown_response.tamil,kb.unknown_response.tanglish),contactLink);
   if(matches('private'))return card('private');
   if(matches('product')||(!ranked.length&&continuation&&context.product))
    return card('product',(kb.products||[]).find(p=>p.id==='defensowrix').answer);
   if(matches('domain'))return card('domain');
   if(matches('support'))return card('support');
   if(any(q,['certified','certificate','certification','partnership','guarantee','guaranteed','release date','sla','office hours']))return {...unknown(),final:true};
   if(matches('pricing'))return card('pricing',null,active?.id);
   if(matches('ai_core'))return card('ai_core',null,'ai-automation-integration');
   if(matches('consultation'))return card('consultation');
   if(detail&&active){
    const benefits=any(q,['benefits','advantages','uses','nanmai','enna benefit','பயன்கள்']);
    const items=benefits?active.benefits:active.capabilities;
    const heading=say(benefits?'Published benefits':'Published capabilities',benefits?'வெளியிடப்பட்ட பயன்கள்':'வெளியிடப்பட்ட அம்சங்கள்',benefits?'Published benefits':'Published features');
    return result(`${active.name} — ${heading}:\n${items.map(x=>'• '+x).join('\n')}\n\n${say('Confirm the scope with SOWRIX.','சேவையின் வரம்பை SOWRIX அணியுடன் உறுதிசெய்யுங்கள்.','Scope-ah SOWRIX team kitta confirm pannunga.')}`,{href:active.page_link,label:active.name},active.id);
   }
   const follow=ref||any(q,['what next','next steps','how long','timeline','how does it work','process','how do we start','எப்படி தொடங்குவது']);
   if(follow&&active){
    const link={href:active.page_link,label:active.name};
    if(any(q,['how long','timeline','duration','எவ்வளவு காலம்']))return result(say('No fixed delivery timeline is published for '+active.name+'. Scope and scheduling are confirmed after requirements are reviewed.','இந்தச் சேவைக்கான நிர்ணயிக்கப்பட்ட கால அளவு வெளியிடப்படவில்லை. தேவைகளை மதிப்பாய்வு செய்த பிறகு கால அட்டவணை உறுதிசெய்யப்படும்.',active.name+' ku fixed timeline publish pannala. Requirements review panna piragu schedule confirm aagum.'),link,active.id);
    return result(say(`For ${active.name}, start by sharing one current constraint and your desired outcome.\n\n${kb.delivery_approach.slice(0,2).map((step,i)=>`${i+1}. ${step.title}: ${step.text}`).join('\n')}`,
     `${active.name} தொடர்பாக தற்போதைய ஒரு சிக்கலையும் எதிர்பார்க்கும் முடிவையும் குறிப்பிடுங்கள்.\n\n1. தேவைகளைப் புரிந்துகொள்வது.\n2. தீர்வையும் அதன் வரம்பையும் முன்மொழிவது.`,
     `${active.name} ku current problem-um expected outcome-um share pannunga.\n\n1. Requirements review.\n2. Suitable solution-um scope-um propose pannuvanga.`),link,active.id);
   }
   if(/^(hi|hello|hey|vanakkam|வணக்கம்|good morning|good evening)$/.test(q))
    return result(say('I can help you explore SOWRIX services, careers or ways to contact the team. What would you like to know?',
    'வணக்கம்! SOWRIX சேவைகள், வேலைவாய்ப்புகள், தொடர்பு விவரங்கள் மற்றும் புதிய திட்டங்கள் பற்றி கேளுங்கள்.',
    'Vanakkam! SOWRIX services, careers, contact details ellam ketkalaam. Enna help venum?'),servicesLink);
   if(/^(thank you|thanks|nandri|நன்றி)$/.test(q))return result(say('You’re welcome.','மகிழ்ச்சி.','Nandri.'));
  if(any(q,['all services','list services','which services','what services','your services','services provide','services offered','service list','what do you do','enna service','enna ena service','service iruku','சேவைகள்','என்ன சேவை','என்னென்ன']))
   return result(say('SOWRIX lists these six core solution areas:\n'+kb.services.map((x,i)=>`${i+1}. ${x.name}`).join('\n')+'\n\nTell me your business need and I can point you to a suitable service.',
    'SOWRIX வழங்கும் ஆறு முக்கிய தீர்வு பகுதிகள்:\n'+kb.services.map((x,i)=>`${i+1}. ${x.name}`).join('\n')+'\n\nஉங்கள் தேவையைச் சொல்லுங்கள்; சரியான சேவையை அறிமுகப்படுத்துகிறேன்.',
    'SOWRIX-la six core solution areas irukku:\n'+kb.services.map((x,i)=>`${i+1}. ${x.name}`).join('\n')+'\n\nUn business requirement sonna suitable service suggest panren.'),servicesLink);
  if(any(q,['email','mail id','phone','mobile number','telephone','contact number','call','whatsapp number','reach you','contact details','contact','thodarbu','தொடர்பு','மின்னஞ்சல்']))
   return result(say(`SOWRIX Technologies contact:\nEmail: ${co.email}\nPhone: ${co.phones.join(' / ')}\nLocations listed on the website: ${co.locations.join(' and ')}.\nFor a project enquiry, use the Contact page.`,
    `SOWRIX தொடர்பு:\nEmail: ${co.email}\nPhone: ${co.phones.join(' / ')}\nஇடங்கள்: ${co.locations.join(', ')}.\nமேலும் விவரங்களுக்கு Contact பக்கத்தைப் பயன்படுத்துங்கள்.`,
    `SOWRIX contact:\nEmail: ${co.email}\nPhone: ${co.phones.join(' / ')}\nLocations: ${co.locations.join(', ')}.\nProject enquiry-na Contact page use pannunga.`),contactLink);
  if(!ranked.length&&any(q,['where are you','where is your office','location','address','office','chennai','bangalore','bengaluru','which city','enga','எங்கே','இடம்']))
   return result(`SOWRIX website lists ${co.locations.join(' and ')} as business locations. A street address and visiting hours are not verified in this public guide; contact the team before visiting.`,contactLink);
  if(any(q,['who are you','what is sowrix','about sowrix','about company','company details','tell me about sowrix','sowrix technologies','நிறுவனம்','unga company']))
   return result(`${co.name} — “${co.tagline}”\n\n${co.overview}\n\nPublished process: ${co.process}.`,{href:'#/about',label:'About SOWRIX'});
  if(any(q,['book a consultation','consultation','book meeting','appointment','get in touch','start project','project enquiry','need a quotation','talk to team','meet your team','meeting book','consult panna','meeting venum']))
   return result(`To discuss a project, open the Contact page and share your requirement. ${co.lead_policy}`,contactLink);
  if(any(q,['how do you work','your process','work process','project process','development process','steps','how to start','start a project','workflow']))
   return result(`SOWRIX's published process is: ${co.process}. Share your goals in a consultation enquiry; the team will confirm the detailed steps and timeline.`,contactLink);
  if(any(q,['social media','twitter','x account','youtube','social links'])){
   const links=kb.social_links||[];
   if(links.length)return result(links.map(item=>`${item.name}: ${item.url}`).join('\n'),{href:links[0].url,label:links[0].name});
  }
  for(const topic of kb.topics){if(any(q,topic.keywords))return result(tamil?(topic.answer_tamil||topic.answer):tanglish?(topic.answer_tanglish||topic.answer):topic.answer,{href:topic.href,label:'Open '+topic.title});}
   if(ranked.length){const matches=ranked.filter(x=>x.score>=ranked[0].score-1).slice(0,2),specific=matches[0].s;
    const lead=matches.map(x=>`${x.s.name}: ${x.s.description}`).join('\n\n');
    const same=context.service===specific.id;
    return result(say(lead+(same?'':'\n\nWhat result matters most, and what is the main constraint in your current setup?'),
     `உங்கள் தேவைக்கு ${matches.map(x=>x.s.name).join(' / ')} பொருந்தலாம்.${same?'':' எதிர்பார்க்கும் முடிவும் தற்போதைய முக்கியச் சிக்கலும் என்ன?'}`,
     `Unga requirement-ku ${matches.map(x=>x.s.name).join(' / ')} porundhalaam.${same?'':' Expected result-um current setup-la main constraint-um enna?'}`),
     matches.length===1?{href:specific.page_link,label:specific.name}:servicesLink,specific.id);
   }
   if(matches('clarify'))return card('clarify');
  if(any(q,['working hours','office hours','opening time','sunday','saturday','weekend','certified','certificate','partnership','partner','guarantee']))
   return result((kb.unknown_response&&kb.unknown_response.english)||'I could not verify that detail from the published SOWRIX website information. Please contact the team for an accurate answer.',contactLink);
  return result(say((kb.unknown_response&&kb.unknown_response.english)||'I could not verify a specific answer from the published SOWRIX information. You can ask about any of our six core solution areas, projects, contact, careers, solutions or client login. For a custom requirement, the team can help through Contact.',
   (kb.unknown_response&&kb.unknown_response.tamil)||'இந்தக் கேள்விக்கான உறுதிப்படுத்தப்பட்ட விவரம் இணையதளத்தில் இல்லை. சேவைகள், திட்டங்கள், வேலைவாய்ப்பு அல்லது தொடர்பு பற்றி கேட்கலாம்.',
   (kb.unknown_response&&kb.unknown_response.tanglish)||'Indha specific detail website-la verify aagala. Services, projects, careers, contact pathi ketkalaam; custom help-ku Contact use pannunga.'),contactLink);
 };
 const skills=['python','java','javascript','typescript','react','node.js','sql','postgresql','supabase','fastapi','aws','azure','docker','kubernetes','excel','figma','testing','networking','linux','firebase','css','html'];
 const interview={python:'Ask for a small example of handling errors and validating inputs.',java:'Ask about interfaces and safe exception handling.',javascript:'Ask about asynchronous code and DOM safety.',typescript:'Ask how type checking prevents runtime defects.',react:'Ask about state, effects and accessible components.',sql:'Ask for a secure query and explain indexes.',postgresql:'Ask about transactions, constraints and least-privilege access.',supabase:'Ask about row-level security with two organizations.',fastapi:'Ask about request validation, dependency injection and tests.',aws:'Ask about IAM roles and backup recovery.',azure:'Ask about role-based access and deployment checks.',docker:'Ask about non-root containers and image scanning.',testing:'Ask for unit versus integration test examples.',networking:'Ask about DNS, HTTPS and troubleshooting.',linux:'Ask about process permissions and logs.'};
 let launcher=null,panel=null,lastFocus=null,chatDraft=null;
 function speak(text){const out=panel?.querySelector('[data-sx-assist-answer]');if(out)out.textContent=text;}
 function setBody(html){const body=panel.querySelector('[data-sx-assist-body]');body.innerHTML=html;return body;}
 function faqResponse(question){
  if(!panel?.isConnected)return;
  const response=answerFor(question);
  const answer=panel.querySelector('[data-sx-assist-answer]');
  const link=panel.querySelector('[data-sx-assist-link]');
  if(answer)answer.textContent=response.text;
  if(link){link.hidden=!response.href;if(response.href){link.href=response.href;link.textContent=response.link;}}
 }
 function showVisitor(){
  const page=pageAssistant();
  const body=setBody(`<div class="sx-chat-intro"><span class="sx-chat-intro-icon" aria-hidden="true">✦</span><div><h4>SOWRIX AI Assistant</h4><p>${esc(page.description)}</p><p>Explore services, compare solutions, or ask in English, Tamil or Tanglish.</p></div></div>
  <div class="sx-chat-thread" data-sx-chat-thread role="log" aria-live="polite" aria-label="Chat conversation"></div>
  <div class="sx-chat-quick" aria-label="Suggested questions">${page.prompts.map(([label,q])=>`<button type="button" data-sx-chat-prompt="${esc(q)}">${esc(label)}</button>`).join('')}</div>
  <form data-sx-chat-form class="sx-chat-composer"><label for="sx-chat-message" class="sx-chat-label">Your message</label><div class="sx-chat-inputrow"><textarea id="sx-chat-message" name="message" rows="2" maxlength="900" placeholder="Ask anything about SOWRIX…" required aria-describedby="sx-chat-service-note"></textarea><button type="submit" data-sx-chat-send aria-label="Send message"><svg viewBox="0 0 24 24" aria-hidden="true" width="22" height="22" fill="none"><path d="m4 12 16-8-4 16-4-7-8-1Z" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/><path d="m12 13 8-9" stroke="currentColor" stroke-width="1.8"/></svg></button></div></form>
   <div class="sx-chat-utility"><span data-sx-chat-status id="sx-chat-service-note" role="status">Website knowledge · Checking AI service…</span><div class="sx-chat-actions"><button type="button" class="sx-chat-clear" data-sx-chat-clear>Clear conversation</button><button type="button" class="sx-chat-clear" data-sx-chat-export>Export chat</button></div></div>
  <label class="sx-chat-memory"><input type="checkbox" data-sx-chat-memory> Remember chat in this browser tab only (optional; never uploaded for storage)</label>
  <details class="sx-chat-options" data-sx-chat-options hidden><summary>AI privacy &amp; options</summary><label class="sx-chat-consent"><input type="checkbox" data-sx-chat-consent> <span>Use generative AI. Your messages will be sent to the AI provider; avoid sensitive information.</span></label></details>
   <div class="sx-chat-handoff"><a href="${contactHash()}">Talk to our team ↗</a><button type="button" data-sx-chat-handoff>Use conversation for enquiry ↗</button></div>`);
  const thread=body.querySelector('[data-sx-chat-thread]');
  const form=body.querySelector('[data-sx-chat-form]');
  const input=form.elements.message;
  const submit=body.querySelector('[data-sx-chat-send]');
  const consent=body.querySelector('[data-sx-chat-consent]');
  const status=body.querySelector('[data-sx-chat-status]');
  const options=body.querySelector('[data-sx-chat-options]');
  const history=[];
  const memory=body.querySelector('[data-sx-chat-memory]');
  const STORAGE_KEY='sowrix-r4610-session-chat';
  const MEMORY_KEY='sowrix-r4610-memory-opt-in';
  const getSession=(key)=>{try{return sessionStorage.getItem(key);}catch(_){return null;}};
  const setSession=(key,value)=>{try{if(value===null)sessionStorage.removeItem(key);else sessionStorage.setItem(key,value);return true;}catch(_){return false;}};
  memory.checked=getSession(MEMORY_KEY)==='yes';
   const saveHistory=()=>{if(!memory.checked)return;const saved=history.filter(turn=>!turn.editorial).slice(-16);
   if(!setSession(STORAGE_KEY,JSON.stringify(saved)))status.textContent='Browser storage blocked. Chat stays in memory only.';};
  let publishedFaqs=[];
  // A published FAQ must match the actual question, not generic words like "help".
  const faqFor=question=>{const cleaned=normal(question);const words=cleaned.split(' ').filter(x=>x.length>=4&&!['what','how','does','about','have','your','please','with','from','when','where','much','need','want'].includes(x));
   if(!words.length)return null;
   for(const item of publishedFaqs){const q=normal(item.question);const keyWords=q.split(' ').filter(x=>x.length>=4&&!['what','how','does','about','have','your','please','with','from','when','where','much','need','want'].includes(x));
    const common=keyWords.filter(x=>words.includes(x)).length;
    if((cleaned===q)||(common>=2&&common>=Math.ceil(keyWords.length*.70)&&common>=Math.ceil(words.length*.65)))
     return {text:item.answer,href:'',link:'',service:''};
   }return null;};
  let busy=false,controller=null,aiReady=false;
  const bubble=(who,text,label,link)=>{
   const item=document.createElement('div');item.className='sx-chat-msg '+(who==='user'?'sx-chat-user':'sx-chat-bot');
   const title=document.createElement('span');title.className='sx-chat-speaker';title.textContent=label||(who==='user'?'You':'SOWRIX Assist');
   const message=document.createElement('p');message.textContent=text;item.append(title,message);
   if(who!=='user'){
    const copy=document.createElement('button');copy.type='button';copy.className='sx-chat-copy';copy.setAttribute('aria-label','Copy SOWRIX response');copy.textContent='Copy';
    copy.onclick=async()=>{
     try{
      if(navigator.clipboard?.writeText)await navigator.clipboard.writeText(message.textContent);
      else{const selection=document.createElement('textarea');selection.value=message.textContent;selection.setAttribute('readonly','');selection.style.position='fixed';selection.style.opacity='0';document.body.append(selection);selection.select();if(!document.execCommand('copy'))throw Error('Copy command was rejected');selection.remove();}
      copy.textContent='Copied';copy.dataset.copied='true';if(status?.isConnected)status.textContent='Response copied to your clipboard.';
      setTimeout(()=>{if(copy.isConnected){copy.textContent='Copy';delete copy.dataset.copied;}},1600);
     }catch(_){if(status?.isConnected)status.textContent='Copy was unavailable. Select the response text to copy it manually.';}
    };
    item.append(copy);
   }
   if(link?.href){const a=document.createElement('a');a.className='sx-chat-resource';a.href=link.href;a.textContent=link.link+' ↗';item.appendChild(a);}
   thread.append(item);
   thread.scrollTop=thread.scrollHeight;return item;
  };
   let context={};
   const guideFor=q=>{
    const reviewed=answerFor(q,context);
    const answer=!reviewed.final&&Object.values(PUBLIC_KNOWLEDGE.unknown_response).includes(reviewed.text)?(faqFor(q)||reviewed):reviewed;
    if(answer.service||answer.product)context={service:answer.service,product:answer.product};
    else if(!answer.final&&!any(normal(q),['thanks','thank you','nandri','நன்றி']))context={};
    // Keep approved resource links available on follow-up answers.
    return answer;
   };
   const record=(who,text,editorial=false)=>{history.push({role:who,text:String(text).slice(0,1000),...(editorial?{editorial:true}:{})});if(history.length>16)history.shift();saveHistory();};
   async function editorialAnswer(question){
    // Fetch released answers, not the user's question. Never send this material to a model.
    const norm=s=>s.normalize('NFKC').toLowerCase().trim().replace(/\s+/g,' ').replace(/[?! .]+$/,'');
    if(/defensowrix|early\s*access|ஆரம்ப அணுகல்|முன்கூட்டிய அணுகல்/i.test(question))return '';
    try{
     const query=norm(question);
      const lookup=query.match(/^(?:what is |tell me about |விளக்கவும் |sollunga )?(service|industry|solution|portfolio|insight|announcement)\s+([a-z0-9][a-z0-9-]{0,63})$/);
     const phone=/^(?:what is your (?:primary )?phone number|உங்கள் தொலைபேசி எண் என்ன|unga phone number enna)$/.test(query);
      const companyField=/^(what are your business hours|ungal business hours enna|உங்கள் அலுவல் நேரம் என்ன)$/.test(query)?'business-hours':/^(what is your office address|unga office address enna|உங்கள் அலுவலக முகவரி என்ன)$/.test(query)?'office-address':query==='what is your company name'?'company-name':query==='what does sowrix do'?'company-description':'';
     const kind=phone||companyField?'contact':lookup?({service:'services',industry:'industries',solution:'solutions',portfolio:'portfolio',insight:'insights',announcement:'announcements'})[lookup[1]]:'knowledge';
     const response=await fetch('/api/public/editorial/'+kind,{cache:'no-store',signal:AbortSignal.timeout(1400)});
     if(!response.ok)return '';
     const feed=await response.json();if(!Array.isArray(feed.items))return '';
     if(lookup||phone||companyField){
      const item=feed.items.find(x=>x?.slug===(phone?'primary-phone':companyField||lookup[2]));
      if(typeof item?.body!=='string')return '';
      if(phone){
       const number=item.body.trim();if(!/^\+[1-9][0-9]{7,14}$/.test(number))return '';
       return /[\u0b80-\u0bff]/.test(query)?'SOWRIX தொலைபேசி எண்: '+number:query.startsWith('unga')?'SOWRIX phone number: '+number:'The published SOWRIX phone number is '+number+'.';
      }
      return item.body.slice(0,3000);
     }
     for(const item of feed.items.slice(0,100))for(const [key,answer] of [['question_en','body'],['question_ta','answer_ta'],['question_tl','answer_tl']]){
      if(typeof item?.[key]==='string'&&typeof item?.[answer]==='string'&&norm(item[key])===norm(question))return item[answer].slice(0,3000);
     }
    }catch(_){}
    return '';
   }
  const submitQuestion=async(question)=>{
   const msg=String(question||'').trim().slice(0,900);if(!msg||busy)return;
   if(any(normal(msg),PUBLIC_KNOWLEDGE.conversation.cards.private.keywords)||/(?:password|otp|api[_ -]?key|secret)\s*[:=]/i.test(msg)){bubble('assistant','Please do not share passwords, OTPs or API keys here. For account help, contact SOWRIX.','SOWRIX Guide');input.value='';return;}
   busy=true;input.value='';input.disabled=true;submit.disabled=true;
   body.classList.add('sx-chat-has-message');
   bubble('user',msg);
   const pending=bubble('assistant','Looking up your question…','SOWRIX Guide');
    let answer='',mode='guide',notice='',localLink=null,usesEditorial=false;
   try{
    if(consent.checked && aiReady){
     controller=new AbortController();
     const timeout=setTimeout(()=>controller?.abort(),17000);
     try{
       const prior=history.filter(turn=>!turn.editorial).slice(-8);
      while(prior.reduce((sum,turn)=>sum+turn.text.length,0)>4000)prior.shift();
      const response=await fetch('/api/public/assistant/chat',{method:'POST',credentials:'same-origin',
       headers:{'Content-Type':'application/json'},body:JSON.stringify({message:msg,history:prior,consent:true}),signal:controller.signal});
      if(!response.ok)throw Error('Chat service is temporarily unavailable');
      const result=await response.json();
      if(!['guide','ai'].includes(result.mode)||typeof result.reply!=='string'||!result.reply.trim())throw Error('Invalid assistant reply');
      const local=guideFor(msg);mode=result.mode;notice=result.notice||'';
      if(mode==='guide'){answer=local.text;localLink=local;}else{answer=result.reply.slice(0,3500);}
     }finally{clearTimeout(timeout);controller=null;}
    }else{const local=guideFor(msg);answer=local.text;localLink=local;notice='Answer based on published website information.';}
    }catch(_){const local=guideFor(msg);answer=local.text;localLink=local;notice='AI temporarily unavailable. Answer based on published website information.';}
    if(mode==='guide'&&localLink&&!localLink.product&&!localLink.final&&!/private|confidential|password|credential|account/i.test(msg)){
     const reviewed=await editorialAnswer(msg);
     if(reviewed){answer=reviewed;localLink=null;usesEditorial=true;notice='Answer from independently published SOWRIX knowledge.';}
    }
    record('user',msg);record('assistant',answer,usesEditorial);
   if(pending.isConnected){pending.querySelector('.sx-chat-speaker').textContent=mode==='ai'?'SOWRIX AI':'SOWRIX Guide';pending.querySelector('p').textContent=answer;if(localLink?.href){const a=document.createElement('a');a.className='sx-chat-resource';a.href=localLink.href;a.textContent=localLink.link+' ↗';pending.appendChild(a);}}
   if(status.isConnected)status.textContent=notice||(mode==='ai'?'AI answer · Verify important details with SOWRIX.':aiReady?'Website knowledge · Enable AI in options to try generated replies.':'Website knowledge · No live AI on this preview.');
   busy=false;input.disabled=false;submit.disabled=false;
   if(input.isConnected){input.focus();thread.scrollTop=thread.scrollHeight;}
  };
  const restore=()=>{if(!memory.checked)return false;
   try{const saved=JSON.parse(getSession(STORAGE_KEY)||'[]');
    if(!Array.isArray(saved)||saved.length>16||!saved.length)return false;
    if(!saved.every(t=>t&&['user','assistant'].includes(t.role)&&typeof t.text==='string'&&t.text.length<=1000))return false;
    history.push(...saved);body.classList.add('sx-chat-has-message');
    saved.forEach(t=>{if(t.role==='user')guideFor(t.text);bubble(t.role,t.text,t.role==='user'?'You':'SOWRIX Guide');});return true;
   }catch(_){return false;}};
   if(!restore())bubble('assistant','Welcome to SOWRIX Technologies. Tell me what your business needs, or choose a suggested question.','SOWRIX Guide');
  memory.onchange=()=>{setSession(MEMORY_KEY,memory.checked?'yes':null);
   if(memory.checked){saveHistory();status.textContent='Chat saved only within this browser tab; use Clear to erase it.';}
   else{setSession(STORAGE_KEY,null);status.textContent='Session chat memory disabled and erased.';}};
  body.querySelector('[data-sx-chat-export]').onclick=()=>{if(!history.length){status.textContent='Ask a question before exporting a transcript.';return;}
   // Export is initiated by the visitor. No data is sent to SOWRIX or third parties.
   const content='SOWRIX website chat transcript (unverified, not a business agreement)\n\n'+history.map(t=>(t.role==='user'?'Visitor':'SOWRIX Guide')+': '+t.text).join('\n\n');
   const url=URL.createObjectURL(new Blob([content],{type:'text/plain;charset=utf-8'}));
   const a=document.createElement('a');a.href=url;a.download='sowrix-chat-'+new Date().toISOString().slice(0,10)+'.txt';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
  };
  // Published, independently reviewed FAQs are optional; static HTTP preview
  // keeps the bundled website guide and never invents dynamic content.
  fetch('/api/public/assistant/faqs',{credentials:'same-origin',cache:'no-store'})
   .then(r=>r.ok?r.json():null).then(data=>{if(!body.isConnected||!Array.isArray(data?.items))return;
    publishedFaqs=data.items.filter(x=>x&&typeof x.question==='string'&&x.question.length<=180&&typeof x.answer==='string'&&x.answer.length<=1200).slice(0,40);
   }).catch(()=>{});
  form.addEventListener('submit',e=>{e.preventDefault();submitQuestion(input.value);});
  input.addEventListener('keydown',e=>{if(e.key==='Enter'&&!e.shiftKey&&!e.isComposing){e.preventDefault();form.requestSubmit();}});
  body.querySelectorAll('[data-sx-chat-prompt]').forEach(b=>b.onclick=()=>submitQuestion(b.dataset.sxChatPrompt));
   body.querySelector('[data-sx-chat-clear]').onclick=()=>{if(busy)return;thread.replaceChildren();history.length=0;setSession(STORAGE_KEY,null);context={};body.classList.remove('sx-chat-has-message');bubble('assistant','Chat cleared. What would you like to know?');status.textContent='Chat cleared · Session history erased.';};
   body.querySelector('[data-sx-chat-handoff]').onclick=()=>{
   const requests=history.filter(t=>t.role==='user').map(t=>'- '+t.text).join('\n');
   if(!requests){status.textContent='First tell me about your project, then transfer your description to the Contact form.';input.focus();return;}
    // A one-time, page-memory-only draft. The visitor must review and submit.
    if(context.product&&document.getElementById('dw-request-form')){
     window.dispatchEvent(new CustomEvent('sowrix:dw-request-draft',{detail:requests}));
     close();location.hash='#defensowrix-request';return;
    }
   chatDraft=('SOWRIX project enquiry draft — please review before submitting:\n'+requests).slice(0,4000);
    const target=contactHash();
    close();
    if(location.hash!==target)location.hash=target;
    else transferChatDraft();
  };
  // No third-party request until the visitor explicitly opts in and sends a message.
  fetch('/api/public/assistant/status',{credentials:'same-origin',cache:'no-store'})
   .then(r=>r.ok?r.json():null).then(info=>{if(!body.isConnected)return;aiReady=info?.mode==='ai';options.hidden=!aiReady;status.textContent=aiReady?'Website knowledge · Generative AI available in options.':'Website knowledge · Live AI not connected on this host.';})
   .catch(()=>{if(body.isConnected)status.textContent='Website knowledge · Live AI requires the private backend.';});
 }
 function suggestedAdmin(data){
  const todo=[];
  if(num(data.unassigned_tickets))todo.push(`${num(data.unassigned_tickets)} tickets need an authorized assignee.`);
  if(num(data.overdue_tasks))todo.push(`${num(data.overdue_tasks)} tasks are overdue; review owners and due dates.`);
  if(num(data.expiring_amcs))todo.push(`${num(data.expiring_amcs)} AMC contracts expire within 30 days; review renewal plans.`);
  if(num(data.unpaid_invoices))todo.push(`${num(data.unpaid_invoices)} invoices need payment-status reconciliation; do not assume they are paid.`);
  if(num(data.pending_approvals))todo.push(`${num(data.pending_approvals)} requests need an independent authorized review.`);
  return todo.length?todo:['No urgent issue is indicated by these counts. Review the full dashboard before making decisions.'];
 }
 function countsTable(data,keys){return `<dl class="sx-as-counts">${keys.map(([key,label])=>`<div><dt>${esc(label)}</dt><dd>${num(data[key])}</dd></div>`).join('')}</dl>`;}
 async function showAdmin(){
  const generation=++showAdmin.run;
  const body=setBody('<p data-sx-assist-answer role="status">Loading your authorized Admin summary…</p>');
  try{
   const snapshot=await rpc('sowrix_r462_admin_pulse');if(generation!==showAdmin.run||!panel?.isConnected)return;
   body.innerHTML=`<p class="sx-as-assurance">Admin smart insights • Permission-checked totals</p>`+
    countsTable(snapshot,[['open_tickets','Open tickets'],['overdue_tasks','Overdue tasks'],['unassigned_tickets','Unassigned tickets'],['expiring_amcs','AMC renewals'],['pending_approvals','Approvals'],['unpaid_invoices','Open invoices']])+
    `<h4>Suggested priorities (rules, not AI)</h4><ul class="sx-as-priorities">${suggestedAdmin(snapshot).map(x=>`<li>${esc(x)}</li>`).join('')}</ul>
    <button type="button" data-sx-admin-pulse>Open Business Pulse</button>
    <button type="button" data-sx-kb-open>Knowledge Manager (reviewed FAQs)</button>
    <button type="button" data-sx-health-open>System health checks</button>
    <button type="button" data-sx-ai="admin">Generate optional AI commentary</button>
    <p data-sx-assist-answer role="status" aria-live="polite">Gemini is deferred; rules-based summaries remain available.</p>`;
   body.querySelector('[data-sx-admin-pulse]').onclick=()=>window.SOWRIXR462?.openPulse?.().catch(()=>speak('Business Pulse is unavailable.'));
   body.querySelector('[data-sx-ai]').onclick=()=>speak('Gemini AI is deferred. Use the verified Business Pulse summary for now.');
   body.querySelector('[data-sx-kb-open]').onclick=showKnowledgeManager;
   body.querySelector('[data-sx-health-open]').onclick=showSystemHealth;
  }catch(err){body.textContent=err.message;}
 }
 showAdmin.run=0;
 async function faqRpc(name,args){if(!['super_admin','admin'].includes(role())||!window.sowrixSupabase||!user()?.id)throw Error('Admin sign-in required.');
  const {data,error}=await window.sowrixSupabase.rpc(name,args||{});
  if(error)throw Error('FAQ database action unavailable or denied. Verify R46.10 migration and Admin permissions.');return data;}
 async function showKnowledgeManager(){
  if(!['super_admin','admin'].includes(role()))return;
  const b=setBody('<h3>Reviewed SOWRIX FAQs</h3><p>Admins draft public facts. A different Admin must approve publication. Avoid private client details, prices or guarantees unless verified.</p><p role="status" data-sx-kb-state>Loading reviewed FAQ records…</p><div data-sx-kb-content></div><button type="button" data-sx-kb-back>Back to Admin insights</button>');
  b.querySelector('[data-sx-kb-back]').onclick=showAdmin;
  const state=b.querySelector('[data-sx-kb-state]'), content=b.querySelector('[data-sx-kb-content]');
  try{const rows=await faqRpc('sowrix_r4610_faq_board');if(!b.isConnected)return;
   state.textContent='Only approved entries appear publicly. A published answer must be retracted before creating a revised draft.';
   const list=Array.isArray(rows)?rows:[];
   content.innerHTML=`<div class="sx-kb-list">${list.map(x=>`<article class="sx-kb-entry"><strong>${esc(x.question)}</strong><p>${esc(x.answer)}</p><small>${esc(x.category)} · ${esc(x.state)}</small><div class="sx-kb-controls">
    ${x.state==='draft'&&x.is_creator?`<button type="button" data-sx-kb-action="review" data-id="${esc(x.id)}">Submit for independent review</button>`:''}
    ${x.state==='review'&&!x.is_creator?`<button type="button" data-sx-kb-action="publish" data-id="${esc(x.id)}">Approve and publish</button>`:''}
    ${x.state==='published'?`<button type="button" data-sx-kb-action="retract" data-id="${esc(x.id)}">Retract public FAQ</button>`:''}</div></article>`).join('')||'<p>No reviewed FAQs yet. Bundled SOWRIX service information remains available.</p>'}</div>
    <form data-sx-kb-form class="sx-kb-form"><h4>Create FAQ draft</h4><label>Visitor question<input name="question" minlength="8" maxlength="180" required placeholder="How can customers request a consultation?"></label><label>Reviewed public answer<textarea name="answer" minlength="20" maxlength="1200" rows="4" required></textarea></label><label>Category<select name="category"><option>general</option><option>services</option><option>careers</option><option>contact</option><option>support</option><option>privacy</option></select></label><button type="submit">Save draft (not published)</button></form>`;
   const form=content.querySelector('[data-sx-kb-form]');form.onsubmit=async e=>{e.preventDefault();const button=form.querySelector('button[type="submit"]');button.disabled=true;
    try{await faqRpc('sowrix_r4610_faq_apply',{p_action:'draft',p_data:{question:form.elements.question.value,answer:form.elements.answer.value,category:form.elements.category.value}});await showKnowledgeManager();}
    catch(err){state.textContent=err.message;button.disabled=false;}};
   content.querySelectorAll('[data-sx-kb-action]').forEach(btn=>btn.onclick=async()=>{btn.disabled=true;
    try{await faqRpc('sowrix_r4610_faq_apply',{p_action:btn.dataset.sxKbAction,p_data:{id:btn.dataset.id}});await showKnowledgeManager();}
    catch(err){state.textContent=err.message;btn.disabled=false;}});
  }catch(err){state.textContent=err.message;}
 }
 async function showSystemHealth(){if(!['super_admin','admin'].includes(role()))return;
  const b=setBody('<h3>System Health</h3><p>Private, read-only operational checks. Not a production security certification.</p><p data-sx-health-state role="status">Checking secure session and backend…</p><div data-sx-health-list></div><button type="button" data-sx-health-back>Back to Admin insights</button>');
  b.querySelector('[data-sx-health-back]').onclick=showAdmin;
  const out=b.querySelector('[data-sx-health-state]'),list=b.querySelector('[data-sx-health-list]');
  try{const res=await fetch('/api/admin/system-health',{credentials:'same-origin',cache:'no-store'});
   if(!res.ok)throw Error('Health status unavailable: backend Admin session or database migration is not configured.');
   const data=await res.json();if(!b.isConnected)return;
   out.textContent='Checked: '+String(data.checked_at||'')+' · Production certified: no';
   list.innerHTML=`<dl class="sx-kb-health">${(data.checks||[]).map(x=>`<div><dt>${esc(x.name)}</dt><dd>${esc(x.status)}</dd></div>`).join('')}</dl><h4>Still requires live validation</h4><ul>${(data.requires_manual_verification||[]).map(x=>`<li>${esc(x)}</li>`).join('')}</ul>`;
  }catch(err){out.textContent=err.message;}
 }

 async function showHR(){
  const body=setBody(`<p class="sx-as-assurance">HR Assistant • Private, browser-only résumé keyword helper</p>
   <p>Paste text only if you are authorized to process that résumé. Nothing pasted here is uploaded, stored, ranked or used to decide hiring.</p>
   <label for="sx-as-resume">Résumé text (local only)</label><textarea id="sx-as-resume" maxlength="12000" rows="5" placeholder="Paste the relevant technical section only"></textarea>
   <div class="sx-as-inputrow"><button type="button" data-sx-resume>Extract skills and interview topics</button><button type="button" data-sx-resume-clear>Clear</button></div>
   <div data-sx-resume-result role="status" aria-live="polite"></div>
   <hr><button type="button" data-sx-hr-metrics>Show authorized recruitment totals</button>
   <button type="button" data-sx-ai="hr">Generate optional AI recruitment summary</button>
   <div data-sx-assist-answer role="status" aria-live="polite">Final evaluation stays with an authorized HR reviewer.</div>`);
  const textarea=body.querySelector('textarea'),out=body.querySelector('[data-sx-resume-result]');
  body.querySelector('[data-sx-resume]').onclick=()=>{
   const input=textarea.value.slice(0,12000).toLowerCase();
   const found=skills.filter(skill=>new RegExp('(^|[^a-z0-9])'+skill.replace(/[.*+?^${}()|[\]\\]/g,'\\$&')+'(?=$|[^a-z0-9])','i').test(input));
   out.innerHTML=found.length?`<p><strong>Recognized keywords (not verified proficiency):</strong> ${found.map(esc).join(', ')}</p><ul>${found.slice(0,6).map(skill=>`<li>${esc(interview[skill]||`Ask the applicant to explain a recent ${skill} project and their contribution.`)}</li>`).join('')}</ul>`:'No supported technical keywords detected. Review the résumé manually; a missing keyword is not a hiring signal.';
  };
  body.querySelector('[data-sx-resume-clear]').onclick=()=>{textarea.value='';out.replaceChildren();textarea.focus();};
  body.querySelector('[data-sx-hr-metrics]').onclick=async()=>{
    const answer=body.querySelector('[data-sx-assist-answer]');
    try{const d=await rpc('sowrix_r463_hr_snapshot');if(answer.isConnected)answer.textContent=`Open applications: ${num(d.total_open_candidates)}; newly applied: ${num(d.new_candidates)}; under review: ${num(d.under_review)}; shortlisted: ${num(d.shortlisted)}.`;}catch(err){if(answer.isConnected)answer.textContent=err.message;}
  };
  body.querySelector('[data-sx-ai]').onclick=()=>requestAI('hr');
 }
 async function showClient(){
  const body=setBody(`<p class="sx-as-assurance">Smart Client Portal • Your own account scope only</p><p>View your current projects and tickets. Access is enforced by secure-session and row-level checks in the database.</p><button type="button" data-sx-client-refresh>Refresh my summary</button>
   <div data-sx-client-summary role="status" aria-live="polite"></div>
    <div class="sx-as-links"><a href="#/workspace/projects">My projects</a><a href="#/workspace/tickets">Support tickets</a><a href="#/workspace/invoices">Invoices</a></div>`);
  const out=body.querySelector('[data-sx-client-summary]');
  async function load(){out.textContent='Loading authorized counts…';try{const d=await rpc('sowrix_r463_client_snapshot');out.innerHTML=countsTable(d,[['open_projects','Open projects'],['overdue_projects','Projects past target date'],['open_tickets','Open tickets']]);}catch(err){out.textContent=err.message;}}
  body.querySelector('[data-sx-client-refresh]').onclick=load;await load();
 }
 async function requestAI(mode){
  if(!window.SOWRIXSession?.request){speak('Connect the secured SOWRIX backend first.');return;}
  const button=panel?.querySelector(`[data-sx-ai="${mode}"]`);if(!button)return;
  button.disabled=true;speak('Requesting optional count-only AI commentary…');
  try{
   const result=await window.SOWRIXSession.request('/api/assistant/insights',{mode});
    if(button.isConnected)speak(result.text+'\n\nAI suggestions require human review.');
   }catch(err){if(button.isConnected)speak(err.message+' Local summary remains available.');}
  finally{if(button.isConnected)button.disabled=false;}
 }
  function navigateTab(name){
   ++showAdmin.run;
   const allowed=assistantTabs().some(([id])=>id===name);
   if(!allowed)name='visitor';
  panel.querySelectorAll('[data-sx-tab]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.sxTab===name)));
   if(name==='employee'&&user()?.id&&role()==='employee')return setBody(`<p class="sx-as-assurance">Workplace productivity · Guidance only</p><p>Use Tasks to review your assigned work, Attendance to check your own records, and Leave requests to request review. This guide does not read or change workplace records.</p><div class="sx-as-links"><a href="#/workspace/tasks">My tasks</a><a href="#/workspace/attendance">My attendance</a><a href="#/workspace/leaves">My leave requests</a></div>`);
   if(name==='admin')return showAdmin();
  if(name==='hr')return showHR();
  if(name==='client')return showClient();
  return showVisitor();
 }
  function assistantTabs(){
   let tabs=[['visitor','Visitor']];
   if(user()?.id){if(['super_admin','admin'].includes(role()))tabs.push(['admin','Admin']);if(['super_admin','admin','hr','hr_staff','hr_manager'].includes(role()))tabs.push(['hr','HR']);if(role()==='employee')tabs.push(['employee','Employee']);if(role()==='client')tabs.push(['client','Client']);}
   return tabs;
  }
   function open(){if(panel?.isConnected)return;
    document.querySelector('.sx-assist-panel[inert]')?.remove();
   lastFocus=document.activeElement;panel=document.createElement('section');panel.className='sx-assist-panel';
    panel.id='sx-assistant-drawer';panel.setAttribute('role','dialog');panel.setAttribute('aria-modal','true');panel.setAttribute('aria-label','SOWRIX Assistant');
   const tabs=assistantTabs();
  panel.innerHTML=`<header class="sx-assist-head"><span><strong>SOWRIX Assistant</strong><small>Ask about SOWRIX · Website guidance + human support</small></span><button type="button" data-sx-close aria-label="Close assistant">×</button></header>
    <nav class="sx-assist-tabs" aria-label="Assistant mode" ${tabs.length===1?'hidden':''}>${tabs.map(([id,label])=>`<button type="button" data-sx-tab="${id}" aria-pressed="false">${label}</button>`).join('')}</nav>
    <div class="sx-assist-body" data-sx-assist-body></div><footer>Public information only · <a href="#/privacy">Privacy</a></footer>`;
  document.body.appendChild(panel);
  document.body.classList.add('sx-assist-open');
  panel.querySelector('[data-sx-close]').onclick=close;
  panel.querySelectorAll('[data-sx-tab]').forEach(b=>b.onclick=()=>navigateTab(b.dataset.sxTab));
  panel.addEventListener('keydown',e=>{if(e.key==='Escape'){e.preventDefault();close();return;}if(e.key==='Tab'){
    const focus=[...panel.querySelectorAll('button,input,textarea,select,a[href],[tabindex]')].filter(x=>!x.disabled&&x.tabIndex>=0&&x.getClientRects().length);
   if(!focus.length)return;if(e.shiftKey&&document.activeElement===focus[0]){e.preventDefault();focus.at(-1).focus();}
   if(!e.shiftKey&&document.activeElement===focus.at(-1)){e.preventDefault();focus[0].focus();}
  }});
  navigateTab('visitor');panel.querySelector('[data-sx-close]').focus();launcher.setAttribute('aria-expanded','true');
 }
  function contactHash(){return document.getElementById('cf-message')?'#contact':'#/contact';}
  function transferChatDraft(){
   const target=contactHash(),draft=chatDraft;
   if(!draft||location.hash!==target)return;
   let attempts=0;
   function fill(){
    if(chatDraft!==draft)return;
    if(location.hash!==target){chatDraft=null;return;}
    const field=document.getElementById(target==='#contact'?'cf-message':'f-msg');
    if(!field?.getClientRects().length){
     if(++attempts<30)setTimeout(fill,120);
     else chatDraft=null;
     return;
    }
    chatDraft=null;
    const existing=field.value, combined=existing?existing+'\n\n'+draft:draft;
    field.value=field.maxLength>=0?combined.slice(0,field.maxLength).replace(/[\uD800-\uDBFF]$/,''):combined;
    field.dispatchEvent(new Event('input',{bubbles:true}));
    field.scrollIntoView({block:'center'});
    field.focus({preventScroll:true});
   }
   requestAnimationFrame(fill);
 }
  function close(immediate=false){
   if(!panel)return;
   showAdmin.run++;
   const leaving=panel;
   panel=null;
   leaving.removeAttribute('id');
   document.body.classList.remove('sx-assist-open');
   launcher?.setAttribute('aria-expanded','false');
   if(lastFocus?.isConnected)lastFocus.focus();
   lastFocus=null;
   leaving.inert=true;
   leaving.setAttribute('aria-hidden','true');
   if(immediate===true||!leaving.animate||window.matchMedia?.('(prefers-reduced-motion: reduce)').matches){
    leaving.remove();return;
   }
   const animation=leaving.animate([{transform:'translateX(0)',opacity:1},
    {transform:'translateX(calc(100% + 24px))',opacity:0}],{duration:210,easing:'ease-in',fill:'forwards'});
   animation.finished.then(()=>leaving.remove(),()=>leaving.remove());
  }
 function init(){if(document.querySelector('[data-sx-assist-launch]'))return;
  if(document.getElementById('view-home')&&!window.SOWRIXExperience){
   const html=document.documentElement;
   const syncTheme=()=>{html.dataset.sxTheme=html.classList.contains('dark')?'dark':'light';};
   syncTheme();
   new MutationObserver(syncTheme).observe(html,{attributes:true,attributeFilter:['class']});
  }
  launcher=document.createElement('button');launcher.type='button';launcher.className='sx-assist-launch';launcher.dataset.sxAssistLaunch='';
   launcher.setAttribute('aria-label','Open SOWRIX AI chatbot');launcher.setAttribute('aria-haspopup','dialog');launcher.setAttribute('aria-expanded','false');launcher.setAttribute('aria-controls','sx-assistant-drawer');
  launcher.innerHTML='<svg viewBox="0 0 48 48" aria-hidden="true" focusable="false"><path d="M10 10h28a5 5 0 0 1 5 5v17a5 5 0 0 1-5 5H23l-12 7v-7h-1a5 5 0 0 1-5-5V15a5 5 0 0 1 5-5Z" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linejoin="round"/><path d="M24 15l2.5 6.5L33 24l-6.5 2.5L24 33l-2.5-6.5L15 24l6.5-2.5L24 15Z" fill="currentColor"/></svg><span class="sx-chat-icon-badge" aria-hidden="true">AI</span><span class="sx-assist-tip" aria-hidden="true">Ask SOWRIX AI</span>';
  launcher.onclick=()=>panel?.isConnected?close():open();document.body.appendChild(launcher);
  window.addEventListener('hashchange',()=>{if(panel)close();transferChatDraft();});
   window.addEventListener('pagehide',()=>{if(panel)close(true);});
 }
 window.SOWRIXR463={init,faqResponse,suggestedAdmin};
 if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',init,{once:true});else init();
})();
