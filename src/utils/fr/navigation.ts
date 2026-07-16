const navBarLinks = [
  { name: 'Accueil', url: '/fr/' },
  { name: 'Services', url: '/fr/services/' },
  { name: 'À propos', url: '/fr/#about' },
  { name: 'Contact', url: '/fr/contact/' },
];

const footerLinks = [
  {
    section: 'Architecture Cloud',
    links: [
      { name: 'Hébergement AWS EC2', url: '/fr/#about' },
      { name: 'Application Load Balancer', url: '/fr/#about' },
      { name: 'Réseau CloudFront CDN', url: '/fr/#about' },
    ],
  },
  {
    section: 'Projet',
    links: [
      { name: 'À propos de nous', url: '/fr/#about' },
      { name: 'Équipe Alpha', url: '/fr/#contact' },
      { name: 'Dépôt GitHub', url: 'https://github.com/Mustapha-Haadi/internship-cloud-solution-design' },
    ],
  },
];

const socialLinks = {
  facebook: '#',
  x: '#',
  github: 'https://github.com/Mustapha-Haadi/internship-cloud-solution-design',
  google: '#',
  slack: '#',
};

export default {
  navBarLinks,
  footerLinks,
  socialLinks,
};
