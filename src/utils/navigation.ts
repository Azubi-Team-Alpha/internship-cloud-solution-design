// An array of links for navigation bar
const navBarLinks = [
  { name: 'Home', url: '/' },
  { name: 'Services', url: '/services/' },
  { name: 'About', url: '/#about' },
  { name: 'Contact', url: '/contact/' },
];
// An array of links for footer
const footerLinks = [
  {
    section: 'Cloud Architecture',
    links: [
      { name: 'AWS EC2 hosting', url: '/#about' },
      { name: 'Application Load Balancer', url: '/#about' },
      { name: 'CloudFront CDN', url: '/#about' },
    ],
  },
  {
    section: 'Project',
    links: [
      { name: 'About us', url: '/#about' },
      { name: 'Team Alpha', url: '/#contact' },
      { name: 'GitHub repository', url: 'https://github.com/Mustapha-Haadi/internship-cloud-solution-design' },
    ],
  },
];
// An object of links for social icons
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
